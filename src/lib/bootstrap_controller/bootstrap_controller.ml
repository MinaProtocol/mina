open Core
open Async
open Coda_base
open Coda_state
open Pipe_lib.Strict_pipe

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t

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
    Coda_intf.Network_intf
    with type external_transition := External_transition.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t

  module Sync_handler :
    Coda_intf.Sync_handler_intf
    with type external_transition := External_transition.t
     and type external_transition_validated := External_transition.Validated.t
     and type transition_frontier := Transition_frontier.t
     and type parallel_scan_state := Staged_ledger.Scan_state.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type verifier := Verifier.t
end

module Make (Inputs : Inputs_intf) : sig
  open Inputs

  include
    Coda_intf.Bootstrap_controller_intf
    with type network := Network.t
     and type verifier := Verifier.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation

  module For_tests : sig
    type t

    val make_bootstrap :
         logger:Logger.t
      -> trust_system:Trust_system.t
      -> verifier:Verifier.t
      -> genesis_root:External_transition.Validated.t
      -> network:Network.t
      -> t

    val on_transition :
         t
      -> sender:Unix.Inet_addr.t
      -> root_sync_ledger:( State_hash.t
                          * Unix.Inet_addr.t
                          * Staged_ledger_hash.t )
                          Root_sync_ledger.t
      -> External_transition.t
      -> [> `Syncing_new_snarked_ledger | `Updating_root_transition | `Ignored]
         Deferred.t

    val run :
         logger:Logger.t
      -> trust_system:Trust_system.t
      -> verifier:Verifier.t
      -> network:Network.t
      -> frontier:Transition_frontier.t
      -> ledger_db:Ledger.Db.t
      -> transition_reader:( [< `Transition of
                                External_transition.with_initial_validation
                                Envelope.Incoming.t ]
                           * [< `Time_received of Block_time.t] )
                           Pipe_lib.Strict_pipe.Reader.t
      -> should_ask_best_tip:bool
      -> ( Transition_frontier.t
         * External_transition.with_initial_validation Envelope.Incoming.t list
         )
         Deferred.t

    module Transition_cache :
      Transition_cache.S
      with type external_transition_with_initial_validation :=
                  External_transition.with_initial_validation
       and type state_hash := State_hash.t

    val sync_ledger :
         t
      -> root_sync_ledger:( State_hash.t
                          * Unix.Inet_addr.t
                          * Staged_ledger_hash.t )
                          Root_sync_ledger.t
      -> transition_graph:Transition_cache.t
      -> sync_ledger_reader:( [< `Transition of
                                 External_transition.with_initial_validation
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
    ; verifier: Verifier.t
    ; mutable best_seen_transition: External_transition.with_initial_validation
    ; mutable current_root: External_transition.with_initial_validation
    ; network: Network.t }

  module Transition_cache = Transition_cache.Make (Inputs)

  let worth_getting_root t candidate =
    `Take
    = Consensus.Hooks.select
        ~logger:
          (Logger.extend t.logger
             [ ( "selection_context"
               , `String "Bootstrap_controller.worth_getting_root" ) ])
        ~existing:
          ( t.best_seen_transition |> fst |> With_hash.data
          |> External_transition.protocol_state
          |> Protocol_state.consensus_state )
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

  let start_sync_job_with_peer ~sender ~root_sync_ledger t peer_best_tip
      peer_root =
    let%bind () =
      Trust_system.(
        record t.trust_system t.logger sender
          Actions.
            ( Fulfilled_request
            , Some ("Received verified peer root and best tip", []) ))
    in
    t.best_seen_transition <- peer_best_tip ;
    t.current_root <- peer_root ;
    let blockchain_state =
      t.current_root |> fst |> With_hash.data
      |> External_transition.protocol_state |> Protocol_state.blockchain_state
    in
    let expected_staged_ledger_hash =
      blockchain_state |> Blockchain_state.staged_ledger_hash
    in
    let snarked_ledger_hash =
      blockchain_state |> Blockchain_state.snarked_ledger_hash
    in
    return
    @@
    match
      Root_sync_ledger.new_goal root_sync_ledger
        (Frozen_ledger_hash.to_ledger_hash snarked_ledger_hash)
        ~data:
          ( With_hash.hash (fst t.current_root)
          , sender
          , expected_staged_ledger_hash )
        ~equal:(fun (hash1, _, _) (hash2, _, _) -> State_hash.equal hash1 hash2)
    with
    | `New ->
        `Syncing_new_snarked_ledger
    | `Update_data ->
        `Updating_root_transition
    | `Repeat ->
        `Ignored

  let on_transition t ~sender ~root_sync_ledger
      (candidate_transition : External_transition.t) =
    let candidate_state =
      External_transition.protocol_state candidate_transition
      |> Protocol_state.consensus_state
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
          @@ Logger.error t.logger ~module_:__MODULE__ ~location:__LOC__
               ~metadata:[("error", `String (Error.to_string_hum e))]
               !"Could not get the proof of the root transition from the \
                 network: $error"
      | Ok peer_root_with_proof -> (
          match%bind
            Sync_handler.Root.verify ~logger:t.logger ~verifier:t.verifier
              candidate_state peer_root_with_proof
          with
          | Ok (`Root root, `Best_tip best_tip) ->
              if done_syncing_root root_sync_ledger then return `Ignored
              else
                start_sync_job_with_peer ~sender ~root_sync_ledger t best_tip
                  root
          | Error e ->
              return (received_bad_proof t sender e |> Fn.const `Ignored) )

  let sync_ledger t ~root_sync_ledger ~transition_graph ~sync_ledger_reader =
    let query_reader = Root_sync_ledger.query_reader root_sync_ledger in
    let response_writer = Root_sync_ledger.answer_writer root_sync_ledger in
    Network.glue_sync_ledger t.network query_reader response_writer ;
    Reader.iter sync_ledger_reader
      ~f:(fun (`Transition incoming_transition, `Time_received _) ->
        let ({With_hash.data= transition; hash= _}, _)
              : External_transition.with_initial_validation =
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
        let protocol_state = External_transition.protocol_state transition in
        let previous_state_hash =
          Protocol_state.previous_state_hash protocol_state
        in
        Transition_cache.add transition_graph ~parent:previous_state_hash
          incoming_transition ;
        (* TODO: Efficiently limiting the number of green threads in #1337 *)
        if worth_getting_root t (Protocol_state.consensus_state protocol_state)
        then
          Deferred.ignore
          @@ on_transition t ~sender ~root_sync_ledger transition
        else Deferred.unit )

  let download_best_tip ~network ~logger ~trust_system ~verifier
      ({With_hash.data= initial_root_transition; _}, _) =
    let num_peers = 8 in
    let peers = Network.random_peers network num_peers in
    Logger.info logger
      !"Number of peers that we are sampling: %i"
      (List.length peers) ~module_:__MODULE__ ~location:__LOC__ ;
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        let open Deferred.Or_error.Let_syntax in
        let initial_consensus_state =
          External_transition.consensus_state initial_root_transition
        in
        let%bind peer_best_tip =
          Network.get_bootstrappable_best_tip network peer
            initial_consensus_state
        in
        let open Deferred.Let_syntax in
        match%bind
          Sync_handler.Bootstrappable_best_tip.verify ~logger ~verifier
            initial_consensus_state peer_best_tip
        with
        | Ok verified_witness ->
            Deferred.Or_error.return
              (`Verified_witness verified_witness, `Queried_peer peer)
        | Error e ->
            let error_msg =
              sprintf
                !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof for \
                  their best tip"
                peer
            in
            Logger.warn logger !"%s" error_msg ~module_:__MODULE__
              ~location:__LOC__ ;
            ignore
              Trust_system.(
                record trust_system logger peer.host
                  Actions.(Violated_protocol, Some (error_msg, []))) ;
            Deferred.return (Error e) )

  let request_and_sync_best_tip t root_sync_ledger initial_root_transition =
    Logger.info t.logger
      "Requesting peers for their best tip to eagerly start bootstrap"
      ~module_:__MODULE__ ~location:__LOC__ ;
    match%bind
      download_best_tip ~network:t.network ~logger:t.logger
        ~trust_system:t.trust_system ~verifier:t.verifier
        initial_root_transition
    with
    | Ok
        ( `Verified_witness
            ( `Root root_with_validation
            , `Best_tip ((best_tip, _) as best_tip_with_validation) )
        , `Queried_peer queried_peer ) ->
        Logger.info t.logger
          "Syncing with peer's best tip after asking other peers"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("peer", Network_peer.Peer.to_yojson queried_peer)
            ; ("best tip", External_transition.to_yojson best_tip.data) ] ;
        Deferred.ignore
          (start_sync_job_with_peer ~sender:queried_peer.host ~root_sync_ledger
             t best_tip_with_validation root_with_validation)
    | Error e ->
        Logger.info t.logger
          "A sample subset of peers could not give their valid best tip"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("error", `String (Error.to_string_hum e))] ;
        Deferred.unit

  (* We conditionally ask other peers for their best tip. This is for testing
     eager bootstrapping and the regular functionalities of bootstrapping in
     isolation *)
  let rec run ~logger ~trust_system ~verifier ~network ~frontier ~ledger_db
      ~transition_reader ~should_ask_best_tip =
    let sync_ledger_reader, sync_ledger_writer =
      create ~name:"sync ledger pipe"
        (Buffered (`Capacity 50, `Overflow Crash))
    in
    transfer_while_writer_alive transition_reader sync_ledger_writer ~f:Fn.id
    |> don't_wait_for ;
    let initial_breadcrumb = Transition_frontier.root frontier in
    let initial_transition =
      Transition_frontier.Breadcrumb.transition_with_hash initial_breadcrumb
    in
    let initial_root_transition =
      External_transition.Validation.lower initial_transition
        ( (`Time_received, Truth.True ())
        , (`Proof, Truth.True ())
          (* This is a hack, but since we are bootstrapping. I am assuming this would be fine *)
        , ( `Delta_transition_chain
          , Truth.True
              (Non_empty_list.singleton
                 (Transition_frontier.Breadcrumb.parent_hash initial_breadcrumb))
          )
        , (`Frontier_dependencies, Truth.False)
        , (`Staged_ledger_diff, Truth.False) )
    in
    let t =
      { network
      ; logger
      ; trust_system
      ; verifier
      ; best_seen_transition= initial_root_transition
      ; current_root= initial_root_transition }
    in
    let transition_graph = Transition_cache.create () in
    let root_sync_ledger =
      Root_sync_ledger.create ledger_db ~logger:t.logger ~trust_system
    in
    let%bind () =
      if should_ask_best_tip then
        request_and_sync_best_tip t root_sync_ledger initial_root_transition
      else Deferred.unit
    in
    let%bind synced_db, (hash, sender, expected_staged_ledger_hash) =
      sync_ledger t ~root_sync_ledger ~transition_graph ~sync_ledger_reader
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
          (Staged_ledger.Scan_state.hash scan_state)
          expected_merkle_root pending_coinbases
      in
      Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ( "expected_staged_ledger_hash"
            , Staged_ledger_hash.to_yojson expected_staged_ledger_hash )
          ; ( "received_staged_ledger_hash"
            , Staged_ledger_hash.to_yojson received_staged_ledger_hash ) ]
        "Comparing $expected_staged_ledger_hash to $received_staged_ledger_hash" ;
      let%bind () =
        Staged_ledger_hash.equal expected_staged_ledger_hash
          received_staged_ledger_hash
        |> Result.ok_if_true
             ~error:(Error.of_string "received faulty scan state from peer")
        |> Deferred.return
      in
      Staged_ledger.of_scan_state_pending_coinbases_and_snarked_ledger ~logger
        ~verifier ~scan_state
        ~snarked_ledger:(Ledger.of_database synced_db)
        ~expected_merkle_root ~pending_coinbases
    with
    | Error e ->
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
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("error", `String (Error.to_string_hum e))
            ; ("state_hash", State_hash.to_yojson hash)
            ; ( "expected_staged_ledger_hash"
              , Staged_ledger_hash.to_yojson expected_staged_ledger_hash ) ]
          "Failed to find scan state for the transition with hash $state_hash \
           from the peer or received faulty scan state: $error. Retry \
           bootstrap" ;
        Writer.close sync_ledger_writer ;
        run ~logger ~trust_system ~verifier ~network ~frontier ~ledger_db
          ~transition_reader ~should_ask_best_tip
    | Ok root_staged_ledger -> (
        let%bind () =
          Trust_system.(
            record t.trust_system t.logger sender
              Actions.
                ( Fulfilled_request
                , Some ("Received valid scan state from peer", []) ))
        in
        let new_root =
          With_hash.map (fst t.current_root) ~f:(fun root ->
              (* TODO: review the correctness of this action #2480 *)
              let (`I_swear_this_is_safe_see_my_comment root') =
                External_transition.Validated.create_unsafe root
              in
              root' )
        in
        let consensus_state =
          With_hash.data new_root
          |> External_transition.Validated.protocol_state
          |> Protocol_state.consensus_state
        in
        let local_state = Transition_frontier.consensus_local_state frontier in
        match%bind
          match
            Consensus.Hooks.required_local_state_sync ~consensus_state
              ~local_state
          with
          | None ->
              Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ( "local_state"
                    , Consensus.Data.Local_state.to_yojson local_state )
                  ; ( "consensus_state"
                    , Consensus.Data.Consensus_state.Value.to_yojson
                        consensus_state ) ]
                "Not synchronizing consensus local state" ;
              Deferred.return @@ Ok ()
          | Some sync_jobs ->
              Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                "Synchronizing consensus local state" ;
              Consensus.Hooks.sync_local_state ~local_state ~logger
                ~trust_system
                ~random_peers:(fun n ->
                  List.append
                    (Network.peers_by_ip t.network sender)
                    (Network.random_peers t.network n) )
                ~query_peer:
                  { Network_peer.query=
                      (fun peer f query ->
                        Network.query_peer t.network peer f query ) }
                sync_jobs
        with
        | Error e ->
            Logger.error logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:[("error", `String (Error.to_string_hum e))]
              "Local state sync failed: $error. Retry bootstrap" ;
            Writer.close sync_ledger_writer ;
            run ~logger ~trust_system ~verifier ~network ~frontier ~ledger_db
              ~transition_reader ~should_ask_best_tip
        | Ok () ->
            let%map new_frontier =
              Transition_frontier.create ~logger ~root_transition:new_root
                ~root_snarked_ledger:synced_db ~root_staged_ledger
                ~consensus_local_state:local_state
            in
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              "Bootstrap state: complete." ;
            (new_frontier, Transition_cache.data transition_graph) )

  module For_tests = struct
    type nonrec t = t

    let make_bootstrap ~logger ~trust_system ~verifier ~genesis_root ~network =
      let transition_with_hash =
        With_hash.of_data genesis_root
          ~hash_data:
            (Fn.compose Protocol_state.hash
               External_transition.Validated.protocol_state)
      in
      let transition =
        External_transition.Validation.lower transition_with_hash
          ( (`Time_received, Truth.True ())
          , (`Proof, Truth.True ())
          , ( `Delta_transition_chain
            , Truth.True
                ( Non_empty_list.singleton
                @@ External_transition.Validated.parent_hash genesis_root ) )
          , (`Frontier_dependencies, Truth.False)
          , (`Staged_ledger_diff, Truth.False) )
      in
      { logger
      ; trust_system
      ; verifier
      ; best_seen_transition= transition
      ; current_root= transition
      ; network }

    let on_transition = on_transition

    module Transition_cache = Transition_cache

    let sync_ledger = sync_ledger

    let run = run
  end

  let run = run ~should_ask_best_tip:true
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
  module Root_sync_ledger = Sync_ledger.Db
  module Network = Coda_networking
  module Sync_handler = Sync_handler
end)
