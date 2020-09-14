open Core_kernel
open Async_kernel
open Coda_state
open Pipe_lib
open Coda_transition
open O1trace
open Network_peer

let create_bufferred_pipe ?name () =
  Strict_pipe.create ?name (Buffered (`Capacity 50, `Overflow Crash))

let is_transition_for_bootstrap ~logger
    ~(precomputed_values : Precomputed_values.t) frontier new_transition =
  let root_state =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.protocol_state
  in
  let new_state =
    External_transition.Initial_validated.protocol_state new_transition
  in
  let constants = precomputed_values.consensus_constants in
  Consensus.Hooks.should_bootstrap ~constants
    ~existing:(Protocol_state.consensus_state root_state)
    ~candidate:(Protocol_state.consensus_state new_state)
    ~logger:
      (Logger.extend logger
         [ ( "selection_context"
           , `String "Transition_router.is_transition_for_bootstrap" ) ])

let start_transition_frontier_controller ~logger ~trust_system ~verifier
    ~network ~time_controller ~producer_transition_reader
    ~verified_transition_writer ~clear_reader ~collected_transitions
    ~transition_reader_ref ~transition_writer_ref ~frontier_w
    ~precomputed_values frontier =
  [%log info] "Starting Transition Frontier Controller phase" ;
  let ( transition_frontier_controller_reader
      , transition_frontier_controller_writer ) =
    create_bufferred_pipe ~name:"transition frontier controller pipe" ()
  in
  transition_reader_ref := transition_frontier_controller_reader ;
  transition_writer_ref := transition_frontier_controller_writer ;
  Broadcast_pipe.Writer.write frontier_w (Some frontier) |> don't_wait_for ;
  let new_verified_transition_reader =
    trace_recurring "transition frontier controller" (fun () ->
        Transition_frontier_controller.run ~logger ~trust_system ~verifier
          ~network ~time_controller ~collected_transitions ~frontier
          ~network_transition_reader:!transition_reader_ref
          ~producer_transition_reader ~clear_reader ~precomputed_values )
  in
  Strict_pipe.Reader.iter new_verified_transition_reader
    ~f:
      (Fn.compose Deferred.return
         (Strict_pipe.Writer.write verified_transition_writer))
  |> don't_wait_for

let start_bootstrap_controller ~logger ~trust_system ~verifier ~network
    ~time_controller ~producer_transition_reader ~verified_transition_writer
    ~clear_reader ~transition_reader_ref ~transition_writer_ref
    ~consensus_local_state ~frontier_w ~initial_root_transition
    ~persistent_root ~persistent_frontier ~best_seen_transition
    ~precomputed_values =
  [%log info] "Starting Bootstrap Controller phase" ;
  let bootstrap_controller_reader, bootstrap_controller_writer =
    create_bufferred_pipe ~name:"bootstrap controller pipe" ()
  in
  transition_reader_ref := bootstrap_controller_reader ;
  transition_writer_ref := bootstrap_controller_writer ;
  Option.iter best_seen_transition ~f:(fun best_seen_transition ->
      Strict_pipe.Writer.write bootstrap_controller_writer best_seen_transition
  ) ;
  don't_wait_for (Broadcast_pipe.Writer.write frontier_w None) ;
  trace_recurring "bootstrap controller" (fun () ->
      upon
        (Bootstrap_controller.run ~logger ~trust_system ~verifier ~network
           ~consensus_local_state ~transition_reader:!transition_reader_ref
           ~persistent_frontier ~persistent_root ~initial_root_transition
           ~precomputed_values) (fun (new_frontier, collected_transitions) ->
          Strict_pipe.Writer.kill !transition_writer_ref ;
          start_transition_frontier_controller ~logger ~trust_system ~verifier
            ~network ~time_controller ~producer_transition_reader
            ~verified_transition_writer ~clear_reader ~collected_transitions
            ~transition_reader_ref ~transition_writer_ref ~frontier_w
            ~precomputed_values new_frontier ) )

let download_best_tip ~logger ~network ~verifier ~trust_system
    ~most_recent_valid_block_writer ~genesis_constants =
  let num_peers = 8 in
  let%bind peers = Coda_networking.random_peers network num_peers in
  [%log info] "Requesting peers for their best tip to do initialization" ;
  let open Deferred.Option.Let_syntax in
  let%map best_tip =
    Deferred.List.fold peers ~init:None ~f:(fun acc peer ->
        let open Deferred.Let_syntax in
        match%bind Coda_networking.get_best_tip network peer with
        | Error e ->
            [%log debug]
              ~metadata:
                [ ("peer", Network_peer.Peer.to_yojson peer)
                ; ("error", `String (Error.to_string_hum e)) ]
              "Couldn't get best tip from peer: $error" ;
            return acc
        | Ok peer_best_tip -> (
            match%bind
              Best_tip_prover.verify ~verifier peer_best_tip ~genesis_constants
            with
            | Error e ->
                [%log warn]
                  ~metadata:
                    [ ("peer", Network_peer.Peer.to_yojson peer)
                    ; ("error", `String (Error.to_string_hum e)) ]
                  "Peer sent us bad proof for their best tip" ;
                let%map () =
                  Trust_system.(
                    record trust_system logger peer
                      Actions.
                        ( Violated_protocol
                        , Some ("Peer sent us bad proof for their best tip", [])
                        ))
                in
                acc
            | Ok (`Root _, `Best_tip candidate_best_tip) ->
                let enveloped_candidate_best_tip =
                  Envelope.Incoming.wrap_peer ~data:candidate_best_tip
                    ~sender:peer
                in
                return
                @@ Option.merge acc
                     (Option.return enveloped_candidate_best_tip)
                     ~f:(fun enveloped_existing_best_tip
                        enveloped_candidate_best_tip
                        ->
                       let candidate_best_tip =
                         Envelope.Incoming.data enveloped_candidate_best_tip
                       in
                       let existing_best_tip =
                         Envelope.Incoming.data enveloped_existing_best_tip
                       in
                       Coda_networking.fill_first_received_message_signal
                         network ;
                       if
                         External_transition.Initial_validated.compare
                           candidate_best_tip existing_best_tip
                         > 0
                       then (
                         let best_tip_length =
                           External_transition.Initial_validated
                           .blockchain_length candidate_best_tip
                           |> Coda_numbers.Length.to_int
                         in
                         Coda_metrics.Transition_frontier
                         .update_max_blocklength_observed best_tip_length ;
                         don't_wait_for
                         @@ Broadcast_pipe.Writer.write
                              most_recent_valid_block_writer candidate_best_tip ;
                         enveloped_candidate_best_tip )
                       else enveloped_existing_best_tip ) ) )
  in
  best_tip

let load_frontier ~logger ~verifier ~persistent_frontier ~persistent_root
    ~consensus_local_state ~precomputed_values =
  match%map
    Transition_frontier.load ~logger ~verifier ~consensus_local_state
      ~persistent_root ~persistent_frontier ~precomputed_values ()
  with
  | Ok frontier ->
      Some frontier
  | Error `Persistent_frontier_malformed ->
      failwith
        "persistent frontier unexpectedly malformed -- this should not happen \
         with retry enabled"
  | Error `Bootstrap_required ->
      [%log warn]
        "Fast forward has not been implemented. Bootstrapping instead." ;
      None
  | Error (`Failure e) ->
      failwith ("failed to initialize transition frontier: " ^ e)

let wait_for_high_connectivity ~logger ~network ~is_seed =
  let connectivity_time_upperbound = 60.0 in
  let high_connectivity =
    Coda_networking.on_first_high_connectivity network ~f:Fn.id
  in
  Deferred.any
    [ ( high_connectivity
      >>| fun () ->
      [%log info] "Already connected to enough peers, start initialization" )
    ; ( after (Time_ns.Span.of_sec connectivity_time_upperbound)
      >>= fun () ->
      Coda_networking.peers network
      >>| fun peers ->
      if not @@ Deferred.is_determined high_connectivity then
        if List.length peers = 0 then
          if is_seed then
            [%log info]
              ~metadata:
                [ ( "max seconds to wait for high connectivity"
                  , `Float connectivity_time_upperbound ) ]
              "Will start initialization without connecting with too any peers"
          else (
            [%log error]
              "Failed to find any peers during initialization (crashing \
               because this is not a seed node)" ;
            exit 1 )
        else
          [%log info]
            ~metadata:
              [ ("num peers", `Int (List.length peers))
              ; ( "max seconds to wait for high connectivity"
                , `Float connectivity_time_upperbound ) ]
            "Will start initialization without connecting with too many peers"
      ) ]

let initialize ~logger ~network ~is_seed ~is_demo_mode ~verifier ~trust_system
    ~time_controller ~frontier_w ~producer_transition_reader ~clear_reader
    ~verified_transition_writer ~transition_reader_ref ~transition_writer_ref
    ~most_recent_valid_block_writer ~persistent_root ~persistent_frontier
    ~consensus_local_state ~precomputed_values =
  let%bind () =
    if is_demo_mode then return ()
    else wait_for_high_connectivity ~logger ~network ~is_seed
  in
  let genesis_constants =
    Precomputed_values.genesis_constants precomputed_values
  in
  match%bind
    Deferred.both
      (download_best_tip ~logger ~network ~verifier ~trust_system
         ~most_recent_valid_block_writer ~genesis_constants)
      (load_frontier ~logger ~verifier ~persistent_frontier ~persistent_root
         ~consensus_local_state ~precomputed_values)
  with
  | best_tip, None ->
      let%map initial_root_transition =
        Persistent_frontier.(
          with_instance_exn persistent_frontier ~f:Instance.get_root_transition)
        >>| Result.ok_or_failwith
      in
      start_bootstrap_controller ~logger ~trust_system ~verifier ~network
        ~time_controller ~producer_transition_reader
        ~verified_transition_writer ~clear_reader ~transition_reader_ref
        ~consensus_local_state ~transition_writer_ref ~frontier_w
        ~persistent_root ~persistent_frontier ~initial_root_transition
        ~best_seen_transition:best_tip ~precomputed_values
  | None, Some frontier ->
      return
      @@ start_transition_frontier_controller ~logger ~trust_system ~verifier
           ~network ~time_controller ~producer_transition_reader
           ~verified_transition_writer ~clear_reader ~collected_transitions:[]
           ~transition_reader_ref ~transition_writer_ref ~frontier_w
           ~precomputed_values frontier
  | Some best_tip, Some frontier ->
      if
        is_transition_for_bootstrap ~logger frontier
          (best_tip |> Envelope.Incoming.data)
          ~precomputed_values
      then
        let initial_root_transition =
          Transition_frontier.(Breadcrumb.validated_transition (root frontier))
        in
        let%map () = Transition_frontier.close frontier in
        start_bootstrap_controller ~logger ~trust_system ~verifier ~network
          ~time_controller ~producer_transition_reader
          ~verified_transition_writer ~clear_reader ~transition_reader_ref
          ~consensus_local_state ~transition_writer_ref ~frontier_w
          ~persistent_root ~persistent_frontier ~initial_root_transition
          ~best_seen_transition:(Some best_tip) ~precomputed_values
      else
        let root = Transition_frontier.root frontier in
        let%map () =
          match
            Consensus.Hooks.required_local_state_sync
              ~constants:precomputed_values.consensus_constants
              ~consensus_state:
                (Transition_frontier.Breadcrumb.consensus_state root)
              ~local_state:consensus_local_state
          with
          | None ->
              Deferred.unit
          | Some sync_jobs -> (
              match%map
                Consensus.Hooks.sync_local_state
                  ~local_state:consensus_local_state ~logger ~trust_system
                  ~random_peers:(Coda_networking.random_peers network)
                  ~query_peer:
                    { Consensus.Hooks.Rpcs.query=
                        (fun peer rpc query ->
                          Coda_networking.(
                            query_peer network peer.peer_id
                              (Rpcs.Consensus_rpc rpc) query) ) }
                  sync_jobs
              with
              | Error e ->
                  failwith ("Local state sync failed: " ^ Error.to_string_hum e)
              | Ok () ->
                  () )
        in
        start_transition_frontier_controller ~logger ~trust_system ~verifier
          ~network ~time_controller ~producer_transition_reader
          ~verified_transition_writer ~clear_reader
          ~collected_transitions:[best_tip] ~transition_reader_ref
          ~transition_writer_ref ~frontier_w ~precomputed_values frontier

let wait_till_genesis ~logger ~time_controller
    ~(precomputed_values : Precomputed_values.t) =
  let module Time = Block_time in
  let now = Time.now time_controller in
  let consensus_constants = precomputed_values.consensus_constants in
  let genesis_state_timestamp = consensus_constants.genesis_state_timestamp in
  try
    Consensus.Hooks.is_genesis_epoch ~constants:consensus_constants now
    |> Fn.const Deferred.unit
  with Invalid_argument _ ->
    let time_till_genesis = Time.diff genesis_state_timestamp now in
    [%log warn]
      ~metadata:
        [ ( "time_till_genesis"
          , `Int (Int64.to_int_exn (Time.Span.to_ms time_till_genesis)) ) ]
      "Node started before genesis: waiting $time_till_genesis milliseconds \
       before running transition router" ;
    let rec logger_loop () =
      let%bind () = after (Time_ns.Span.of_sec 30.) in
      let now = Time.now time_controller in
      try
        Consensus.Hooks.is_genesis_epoch ~constants:consensus_constants now
        |> Fn.const Deferred.unit
      with Invalid_argument _ ->
        let tm_remaining = Time.diff genesis_state_timestamp now in
        [%log warn]
          "Time before genesis. Waiting $tm_remaining milliseconds before \
           running transition router"
          ~metadata:
            [ ( "tm_remaining"
              , `Int (Int64.to_int_exn @@ Time.Span.to_ms tm_remaining) ) ] ;
        logger_loop ()
    in
    Time.Timeout.await ~timeout_duration:time_till_genesis time_controller
      (logger_loop ())
    |> Deferred.ignore

let run ~logger ~trust_system ~verifier ~network ~is_seed ~is_demo_mode
    ~time_controller ~consensus_local_state ~persistent_root_location
    ~persistent_frontier_location
    ~frontier_broadcast_pipe:(frontier_r, frontier_w)
    ~network_transition_reader ~producer_transition_reader
    ~most_recent_valid_block:( most_recent_valid_block_reader
                             , most_recent_valid_block_writer )
    ~precomputed_values =
  let initialization_finish_signal = Ivar.create () in
  let clear_reader, clear_writer =
    Strict_pipe.create ~name:"clear" Synchronous
  in
  let verified_transition_reader, verified_transition_writer =
    create_bufferred_pipe ~name:"verified transitions" ()
  in
  let transition_reader, transition_writer =
    create_bufferred_pipe ~name:"transition pipe" ()
  in
  let transition_reader_ref = ref transition_reader in
  let transition_writer_ref = ref transition_writer in
  upon (wait_till_genesis ~logger ~time_controller ~precomputed_values)
    (fun () ->
      let valid_transition_reader, valid_transition_writer =
        create_bufferred_pipe ~name:"valid transitions" ()
      in
      Initial_validator.run ~logger ~trust_system ~verifier
        ~transition_reader:network_transition_reader ~valid_transition_writer
        ~initialization_finish_signal ~precomputed_values ;
      let persistent_frontier =
        Transition_frontier.Persistent_frontier.create ~logger ~verifier
          ~time_controller ~directory:persistent_frontier_location
      in
      let persistent_root =
        Transition_frontier.Persistent_root.create ~logger
          ~directory:persistent_root_location
          ~ledger_depth:(Precomputed_values.ledger_depth precomputed_values)
      in
      upon
        (initialize ~logger ~network ~is_seed ~is_demo_mode ~verifier
           ~trust_system ~persistent_frontier ~persistent_root ~time_controller
           ~frontier_w ~producer_transition_reader ~clear_reader
           ~verified_transition_writer ~transition_reader_ref
           ~transition_writer_ref ~most_recent_valid_block_writer
           ~consensus_local_state ~precomputed_values) (fun () ->
          Ivar.fill_if_empty initialization_finish_signal () ;
          let valid_transition_reader1, valid_transition_reader2 =
            Strict_pipe.Reader.Fork.two valid_transition_reader
          in
          don't_wait_for
          @@ Strict_pipe.Reader.iter valid_transition_reader1
               ~f:(fun enveloped_transition ->
                 let incoming_transition =
                   Envelope.Incoming.data enveloped_transition
                 in
                 let current_transition =
                   Broadcast_pipe.Reader.peek most_recent_valid_block_reader
                 in
                 if
                   Consensus.Hooks.select
                     ~constants:precomputed_values.consensus_constants
                     ~existing:
                       (External_transition.Initial_validated.consensus_state
                          current_transition)
                     ~candidate:
                       (External_transition.Initial_validated.consensus_state
                          incoming_transition)
                     ~logger
                   = `Take
                 then
                   Broadcast_pipe.Writer.write most_recent_valid_block_writer
                     incoming_transition
                 else Deferred.unit ) ;
          don't_wait_for
          @@ Strict_pipe.Reader.iter_without_pushback valid_transition_reader2
               ~f:(fun enveloped_transition ->
                 Strict_pipe.Writer.write !transition_writer_ref
                   enveloped_transition ;
                 don't_wait_for
                 @@
                 let incoming_transition =
                   Envelope.Incoming.data enveloped_transition
                 in
                 match Broadcast_pipe.Reader.peek frontier_r with
                 | Some frontier ->
                     if
                       is_transition_for_bootstrap ~logger frontier
                         incoming_transition ~precomputed_values
                     then (
                       Strict_pipe.Writer.kill !transition_writer_ref ;
                       let initial_root_transition =
                         Transition_frontier.(
                           Breadcrumb.validated_transition (root frontier))
                       in
                       let%bind () =
                         Strict_pipe.Writer.write clear_writer `Clear
                       in
                       let%map () = Transition_frontier.close frontier in
                       start_bootstrap_controller ~logger ~trust_system
                         ~verifier ~network ~time_controller
                         ~producer_transition_reader
                         ~verified_transition_writer ~clear_reader
                         ~transition_reader_ref ~transition_writer_ref
                         ~consensus_local_state ~frontier_w ~persistent_root
                         ~persistent_frontier ~initial_root_transition
                         ~best_seen_transition:(Some enveloped_transition)
                         ~precomputed_values )
                     else Deferred.unit
                 | None ->
                     Deferred.unit ) ) ) ;
  (verified_transition_reader, initialization_finish_signal)
