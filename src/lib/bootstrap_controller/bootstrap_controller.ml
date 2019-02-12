open Core
open Async
open Protocols.Coda_pow
open Coda_base
open Pipe_lib.Strict_pipe

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type consensus_local_state := Consensus.Local_state.t

  module Root_sync_ledger :
    Syncable_ledger.S
    with type addr := Ledger.Location.Addr.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t
     and type merkle_tree := Ledger.Db.t
     and type account := Account.t
     and type merkle_path := Ledger.path
     and type query := Sync_ledger.query
     and type answer := Sync_ledger.answer

  module Network :
    Network_intf
    with type peer := Network_peer.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type consensus_state := Consensus.Consensus_state.value
     and type state_body_hash := State_body_hash.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Sync_ledger.query
     and type sync_ledger_answer := Sync_ledger.answer

  module Time : Time_intf

  module Protocol_state_validator :
    Protocol_state_validator_intf
    with type time := Time.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_proof_verified :=
                External_transition.Proof_verified.t
     and type external_transition_verified := External_transition.Verified.t

  module Sync_handler :
    Sync_handler_intf
    with type ledger_hash := Ledger_hash.t
     and type transition_frontier := Transition_frontier.t
     and type syncable_ledger_query := Sync_ledger.query
     and type syncable_ledger_answer := Sync_ledger.answer

  module Root_prover :
    Root_prover_intf
    with type state_body_hash := State_body_hash.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition := External_transition.t
     and type proof_verified_external_transition :=
                External_transition.Proof_verified.t
     and type consensus_state := Consensus.Consensus_state.value
     and type state_hash := State_hash.t
end

module Make (Inputs : Inputs_intf) : sig
  open Inputs

  include
    Bootstrap_controller_intf
    with type network := Inputs.Network.t
     and type transition_frontier := Inputs.Transition_frontier.t
     and type external_transition_verified :=
                Inputs.External_transition.Verified.t
     and type ledger_db := Ledger.Db.t

  module For_tests : sig
    type t

    val make_bootstrap :
         logger:Logger.t
      -> genesis_root:Inputs.External_transition.Proof_verified.t
      -> network:Inputs.Network.t
      -> t

    val on_transition :
         t
      -> sender:Network_peer.Peer.t
      -> root_sync_ledger:Root_sync_ledger.t
      -> External_transition.Proof_verified.t
      -> [> `Syncing | `Ignored] Deferred.t

    module Transition_cache : sig
      include
        Transition_cache.S
        with type external_transition_verified :=
                    Inputs.External_transition.Verified.t
         and type state_hash := State_hash.t
    end

    val sync_ledger :
         t
      -> root_sync_ledger:Inputs.Root_sync_ledger.t
      -> transition_graph:Transition_cache.t
      -> transition_reader:( [< `Transition of Inputs.External_transition
                                               .Verified
                                               .t
                                               Envelope.Incoming.t ]
                           * [< `Time_received of 'a] )
                           Pipe_lib.Strict_pipe.Reader.t
      -> unit Deferred.t
  end
end = struct
  open Inputs

  type t =
    { logger: Logger.t
    ; mutable best_seen_transition: External_transition.Proof_verified.t
    ; mutable current_root: External_transition.Proof_verified.t
    ; network: Network.t }

  module Transition_cache = Transition_cache.Make (Inputs)

  let worth_getting_root t candidate =
    `Take
    = Consensus.select ~logger:t.logger
        ~existing:
          ( t.best_seen_transition
          |> External_transition.Proof_verified.protocol_state
          |> Consensus.Protocol_state.consensus_state )
        ~candidate

  let received_bad_proof t e =
    (* TODO: Punish *)
    Logger.faulty_peer t.logger !"Bad ancestor proof: %{sexp:Error.t}" e

  let done_syncing_root root_sync_ledger =
    Option.is_some (Root_sync_ledger.peek_valid_tree root_sync_ledger)

  let on_transition t ~sender ~root_sync_ledger
      (candidate_transition : External_transition.Proof_verified.t) =
    let candidate_state =
      External_transition.Proof_verified.protocol_state candidate_transition
      |> Consensus.Protocol_state.consensus_state
    in
    if
      done_syncing_root root_sync_ledger
      || (not @@ worth_getting_root t candidate_state)
    then Deferred.return `Ignored
    else
      match%bind Network.get_ancestry t.network sender candidate_state with
      | Error e ->
          Deferred.return
          @@ Fn.const `Ignored
          @@ Logger.error t.logger
               !"Could not get the proof of root from the network: %s"
               (Error.to_string_hum e)
      | Ok peer_root_with_proof -> (
          match%map
            Root_prover.verify ~logger:t.logger ~observed_state:candidate_state
              ~peer_root:peer_root_with_proof
          with
          | Ok (peer_root, peer_best_tip) ->
              t.best_seen_transition <- peer_best_tip |> With_hash.data ;
              t.current_root <- peer_root |> With_hash.data ;
              let ledger_hash =
                Consensus.(
                  External_transition.Protocol_state.blockchain_state
                    (External_transition.Proof_verified.protocol_state
                       t.current_root)
                  |> Blockchain_state.snarked_ledger_hash
                  |> Frozen_ledger_hash.to_ledger_hash)
              in
              Root_sync_ledger.new_goal root_sync_ledger ledger_hash
              |> Fn.const `Syncing
          | Error e -> received_bad_proof t e |> Fn.const `Ignored )

  (* TODO: We need to do catchup jobs for all remaining transitions in the cache. 
           This will be hooked into `run` when we do this. #1326 *)
  let _expand_root ~logger ~frontier root_hash cache =
    let rec dfs parent =
      let parent_hash =
        With_hash.hash
          (Transition_frontier.Breadcrumb.transition_with_hash parent)
      in
      match Hashtbl.find_and_remove cache parent_hash with
      | None -> Deferred.return ()
      | Some children ->
          Deferred.List.iter children ~f:(fun transition_with_hash ->
              let%bind breadcrumb =
                match%map
                  Transition_frontier.Breadcrumb.build ~logger ~parent
                    ~transition_with_hash
                with
                | Error (`Validation_error e) -> (*TODO: Punish*) Error.raise e
                | Error (`Fatal_error e) -> raise e
                | Ok breadcrumb -> breadcrumb
              in
              Transition_frontier.add_breadcrumb_exn frontier breadcrumb ;
              dfs breadcrumb )
    in
    dfs (Transition_frontier.find_exn frontier root_hash)

  let sync_ledger t ~root_sync_ledger ~transition_graph ~transition_reader =
    let query_reader = Root_sync_ledger.query_reader root_sync_ledger in
    let response_writer = Root_sync_ledger.answer_writer root_sync_ledger in
    Network.glue_sync_ledger t.network query_reader response_writer ;
    Reader.iter transition_reader
      ~f:(fun (`Transition incoming_transition, `Time_received _) ->
        let (transition : External_transition.Verified.t) =
          Envelope.Incoming.data incoming_transition
        in
        let sender = Envelope.Incoming.sender incoming_transition in
        let protocol_state =
          External_transition.Verified.protocol_state transition
        in
        let previous_state_hash =
          External_transition.Protocol_state.previous_state_hash protocol_state
        in
        Transition_cache.add transition_graph ~parent:previous_state_hash
          transition ;
        (* TODO: Efficiently limiting the number of green threads in #1337 *)
        if
          worth_getting_root t
            (Consensus.Protocol_state.consensus_state protocol_state)
        then
          on_transition t ~sender ~root_sync_ledger
            (External_transition.forget_consensus_state_verification transition)
          |> Deferred.map ~f:(Fn.const ())
          |> don't_wait_for ;
        Deferred.unit )

  let run ~parent_log ~network ~frontier ~ledger_db ~transition_reader =
    let logger = Logger.child parent_log __MODULE__ in
    let initial_breadcrumb = Transition_frontier.root frontier in
    let initial_root_transition =
      initial_breadcrumb |> Transition_frontier.Breadcrumb.transition_with_hash
      |> With_hash.data
      |> External_transition.forget_consensus_state_verification
    in
    let t =
      { network
      ; logger
      ; best_seen_transition= initial_root_transition
      ; current_root= initial_root_transition }
    in
    let transition_graph = Transition_cache.create () in
    Transition_frontier.clear_paths frontier ;
    let%bind synced_db =
      let root_sync_ledger =
        Root_sync_ledger.create ledger_db ~parent_log:t.logger
      in
      sync_ledger t ~root_sync_ledger ~transition_graph ~transition_reader
      |> don't_wait_for ;
      let%map synced_db = Root_sync_ledger.valid_tree root_sync_ledger in
      Root_sync_ledger.destroy root_sync_ledger ;
      synced_db
    in
    assert (Ledger.Db.(merkle_root ledger_db = merkle_root synced_db)) ;
    (* Need to coerce new_root from a proof_verified transition to a fully
       verified transition because it will be added into transition frontier*)
    let (`I_swear_this_is_safe_see_my_comment new_root) =
      External_transition.(t.current_root |> of_proof_verified |> to_verified)
    in
    Transition_frontier.create ~logger:parent_log
      ~root_snarked_ledger:ledger_db
      ~root_transaction_snark_scan_state:(Staged_ledger.Scan_state.empty ())
      ~root_staged_ledger_diff:None
      ~root_transition:
        (With_hash.of_data new_root
           ~hash_data:
             (Fn.compose Consensus.Protocol_state.hash
                External_transition.Verified.protocol_state))
      ~consensus_local_state:
        (Transition_frontier.consensus_local_state frontier)

  module For_tests = struct
    type nonrec t = t

    let make_bootstrap ~logger ~genesis_root ~network =
      { logger
      ; best_seen_transition= genesis_root
      ; current_root= genesis_root
      ; network }

    let on_transition = on_transition

    module Transition_cache = Transition_cache

    let sync_ledger = sync_ledger
  end
end
