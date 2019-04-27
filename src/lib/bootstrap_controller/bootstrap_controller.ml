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
     and type user_command := User_command.t
     and type diff_mutant :=
                ( External_transition.Stable.Latest.t
                , State_hash.Stable.Latest.t )
                With_hash.t
                Diff_mutant.E.t

  module Root_sync_ledger :
    Syncable_ledger.S
    with type addr := Ledger.Location.Addr.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t
     and type merkle_tree := Ledger.Db.t
     and type account := Account.t
     and type merkle_path := Ledger.path
     and type query := Sync_ledger.Query.t
     and type answer := Sync_ledger.Answer.t

  module Network :
    Network_intf
    with type peer := Network_peer.Peer.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type consensus_state := Consensus.Consensus_state.Value.t
     and type state_body_hash := State_body_hash.t
     and type ledger_hash := Ledger_hash.t
     and type sync_ledger_query := Sync_ledger.Query.t
     and type sync_ledger_answer := Sync_ledger.Answer.t
     and type parallel_scan_state := Staged_ledger.Scan_state.t
     and type pending_coinbases := Pending_coinbase.t

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
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type transition_frontier := Transition_frontier.t
     and type syncable_ledger_query := Sync_ledger.Query.t
     and type syncable_ledger_answer := Sync_ledger.Answer.t
     and type pending_coinbases := Pending_coinbase.t
     and type parallel_scan_state := Staged_ledger.Scan_state.t

  module Root_prover :
    Root_prover_intf
    with type state_body_hash := State_body_hash.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition := External_transition.t
     and type proof_verified_external_transition :=
                External_transition.Proof_verified.t
     and type consensus_state := Consensus.Consensus_state.Value.t
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
      -> trust_system:Trust_system.t
      -> genesis_root:Inputs.External_transition.Proof_verified.t
      -> network:Inputs.Network.t
      -> t

    val on_transition :
         t
      -> sender:Unix.Inet_addr.t
      -> root_sync_ledger:( State_hash.t
                          * Unix.Inet_addr.t
                          * Staged_ledger_hash.t )
                          Root_sync_ledger.t
      -> External_transition.Proof_verified.t
      -> [> `Syncing_new_snarked_ledger | `Updating_root_transition | `Ignored]
         Deferred.t

    module Transition_cache : sig
      include
        Transition_cache.S
        with type external_transition_verified :=
                    Inputs.External_transition.Verified.t
         and type state_hash := State_hash.t
    end

    val sync_ledger :
         t
      -> root_sync_ledger:( State_hash.t
                          * Unix.Inet_addr.t
                          * Staged_ledger_hash.t )
                          Inputs.Root_sync_ledger.t
      -> transition_graph:Transition_cache.t
      -> transition_reader:( [< `Transition of
                                Inputs.External_transition.Verified.t
                                Envelope.Incoming.t ]
                           * [< `Time_received of 'a] )
                           Pipe_lib.Strict_pipe.Reader.t
      -> unit Deferred.t
  end
end = struct
  open Inputs

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; mutable best_seen_transition:
        (External_transition.Proof_verified.t, State_hash.t) With_hash.t
    ; mutable current_root:
        (External_transition.Proof_verified.t, State_hash.t) With_hash.t
    ; network: Network.t }

  module Transition_cache = Transition_cache.Make (Inputs)

  let worth_getting_root t candidate =
    `Take
    = Consensus.select
        ~logger:
          (Logger.extend t.logger
             [ ( "selection_context"
               , `String "Bootstrap_controller.worth_getting_root" ) ])
        ~existing:
          ( t.best_seen_transition |> With_hash.data
          |> External_transition.Proof_verified.protocol_state
          |> Consensus.Protocol_state.consensus_state )
        ~candidate

  let received_bad_proof t sender_host e =
    Trust_system.(
      record t.trust_system t.logger sender_host
        Actions.
          ( Violated_protocol
          , Some
              ( "Bad ancestor proof: $error"
              , [("error", `String (Error.to_string_hum e))] ) ))

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
          match%bind
            Root_prover.verify ~logger:t.logger ~observed_state:candidate_state
              ~peer_root:peer_root_with_proof
          with
          | Ok (peer_root, peer_best_tip) -> (
              let%bind () =
                Trust_system.(
                  record t.trust_system t.logger sender
                    Actions.
                      ( Fulfilled_request
                      , Some ("Received verified peer root and best tip", [])
                      ))
              in
              t.best_seen_transition <- peer_best_tip ;
              t.current_root <- peer_root ;
              let blockchain_state =
                let open External_transition in
                t.current_root |> With_hash.data
                |> Proof_verified.protocol_state
                |> Protocol_state.blockchain_state
              in
              let expected_staged_ledger_hash =
                blockchain_state
                |> External_transition.Protocol_state.Blockchain_state
                   .staged_ledger_hash
              in
              let snarked_ledger_hash =
                blockchain_state
                |> External_transition.Protocol_state.Blockchain_state
                   .snarked_ledger_hash
              in
              return
              @@
              match
                Root_sync_ledger.new_goal root_sync_ledger
                  (Frozen_ledger_hash.to_ledger_hash snarked_ledger_hash)
                  ~data:
                    ( With_hash.hash t.current_root
                    , sender
                    , expected_staged_ledger_hash )
                  ~equal:(fun (hash1, _, _) (hash2, _, _) ->
                    State_hash.equal hash1 hash2 )
              with
              | `New ->
                  `Syncing_new_snarked_ledger
              | `Update_data ->
                  `Updating_root_transition
              | `Repeat ->
                  `Ignored )
          | Error e ->
              return (received_bad_proof t sender e |> Fn.const `Ignored) )

  let sync_ledger t ~root_sync_ledger ~transition_graph ~transition_reader =
    let query_reader = Root_sync_ledger.query_reader root_sync_ledger in
    let response_writer = Root_sync_ledger.answer_writer root_sync_ledger in
    Network.glue_sync_ledger t.network query_reader response_writer ;
    Reader.iter transition_reader
      ~f:(fun (`Transition incoming_transition, `Time_received _) ->
        let (transition : External_transition.Verified.t) =
          Envelope.Incoming.data incoming_transition
        in
        let sender =
          match Envelope.Incoming.sender incoming_transition with
          | Envelope.Sender.Local ->
              failwith
                "Unexpected, we should be syncing only to remote nodes in \
                 sync ledger"
          | Envelope.Sender.Remote inet_addr ->
              inet_addr
        in
        let protocol_state =
          External_transition.Verified.protocol_state transition
        in
        let previous_state_hash =
          External_transition.Protocol_state.previous_state_hash protocol_state
        in
        Transition_cache.add transition_graph ~parent:previous_state_hash
          incoming_transition ;
        (* TODO: Efficiently limiting the number of green threads in #1337 *)
        if
          worth_getting_root t
            (Consensus.Protocol_state.consensus_state protocol_state)
        then
          Deferred.ignore
          @@ on_transition t ~sender ~root_sync_ledger
               (External_transition.forget_consensus_state_verification
                  transition)
        else Deferred.unit )

  let run ~logger ~trust_system ~network ~frontier ~ledger_db
      ~transition_reader =
    let initial_breadcrumb = Transition_frontier.root frontier in
    let initial_root_verified_transition =
      initial_breadcrumb |> Transition_frontier.Breadcrumb.transition_with_hash
    in
    let initial_root_transition =
      With_hash.map initial_root_verified_transition
        ~f:External_transition.forget_consensus_state_verification
    in
    let t =
      { network
      ; logger
      ; trust_system
      ; best_seen_transition= initial_root_transition
      ; current_root= initial_root_transition }
    in
    let transition_graph = Transition_cache.create () in
    let%bind synced_db, (hash, sender, expected_staged_ledger_hash) =
      let root_sync_ledger =
        Root_sync_ledger.create ledger_db ~logger:t.logger ~trust_system
      in
      sync_ledger t ~root_sync_ledger ~transition_graph ~transition_reader
      |> don't_wait_for ;
      let%map synced_db, root_data =
        Root_sync_ledger.valid_tree root_sync_ledger
      in
      Root_sync_ledger.destroy root_sync_ledger ;
      (synced_db, root_data)
    in
    assert (
      Ledger.Db.(
        Ledger_hash.equal (merkle_root ledger_db) (merkle_root synced_db)) ) ;
    match%bind
      let open Deferred.Or_error.Let_syntax in
      let%bind scan_state, expected_merkle_root, pending_coinbases =
        Network.get_staged_ledger_aux_and_pending_coinbases_at_hash t.network
          sender hash
      in
      let received_staged_ledger_hash =
        Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
          (Staged_ledger_hash.Aux_hash.of_bytes
             (Staged_ledger_aux_hash.to_bytes
                (Staged_ledger.Scan_state.hash scan_state)))
          expected_merkle_root pending_coinbases
      in
      let%bind () =
        Staged_ledger_hash.equal expected_staged_ledger_hash
          received_staged_ledger_hash
        |> Result.ok_if_true
             ~error:(Error.of_string "received faulty scan state from peer")
        |> Deferred.return
      in
      Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger
        ~scan_state
        ~snarked_ledger:(Ledger.of_database synced_db)
        ~expected_merkle_root ~pending_coinbases
    with
    | Error err ->
        let%bind () =
          Trust_system.(
            record t.trust_system t.logger sender
              Actions.
                ( Violated_protocol
                , Some
                    ( "Can't find scan state from the peer or received faulty \
                       scan state from the peer."
                    , [] ) ))
        in
        Error.raise err
    | Ok root_staged_ledger ->
        let%bind () =
          Trust_system.(
            record t.trust_system t.logger sender
              Actions.
                ( Fulfilled_request
                , Some ("Received valid scan state from peer", []) ))
        in
        let new_root =
          With_hash.map t.current_root ~f:(fun root ->
              (* Need to coerce new_root from a proof_verified transition to a
             fully verified transition because it will be added into transition
             frontier*)
              let (`I_swear_this_is_safe_see_my_comment verified_root) =
                External_transition.(root |> of_proof_verified |> to_verified)
              in
              verified_root )
        in
        let%map new_frontier =
          Transition_frontier.create ~logger ~root_transition:new_root
            ~root_snarked_ledger:synced_db ~root_staged_ledger
            ~consensus_local_state:
              (Transition_frontier.consensus_local_state frontier)
        in
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__
          "Bootstrap state: complete." ;
        (new_frontier, Transition_cache.data transition_graph)

  module For_tests = struct
    type nonrec t = t

    let hash_data =
      Fn.compose Consensus.Protocol_state.hash
        External_transition.Proof_verified.protocol_state

    let make_bootstrap ~logger ~trust_system ~genesis_root ~network =
      let transition = With_hash.of_data genesis_root ~hash_data in
      { logger
      ; trust_system
      ; best_seen_transition= transition
      ; current_root= transition
      ; network }

    let on_transition = on_transition

    module Transition_cache = Transition_cache

    let sync_ledger = sync_ledger
  end
end
