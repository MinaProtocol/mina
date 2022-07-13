open Core_kernel
open Async_kernel
open Pipe_lib
open Mina_block
open Network_peer
open Mina_numbers

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

type Structured_log_events.t += Starting_transition_frontier_controller
  [@@deriving
    register_event { msg = "Starting transition frontier controller phase" }]

type Structured_log_events.t += Starting_bootstrap_controller
  [@@deriving register_event { msg = "Starting bootstrap controller phase" }]

let create_bufferred_pipe ?name ~f () =
  Strict_pipe.create ?name (Buffered (`Capacity 50, `Overflow (Drop_head f)))

let is_transition_for_bootstrap ~context:(module Context : CONTEXT) frontier
    new_transition =
  let root_consensus_state =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.consensus_state_with_hashes
  in
  let new_consensus_state =
    Validation.block_with_hash new_transition
    |> With_hash.map ~f:Mina_block.consensus_state
  in
  match
    Consensus.Hooks.select
      ~context:(module Context)
      ~existing:root_consensus_state ~candidate:new_consensus_state
  with
  | `Keep ->
      false
  | `Take ->
      let slack = 5 in
      if
        Length.to_int
          ( Transition_frontier.best_tip frontier
          |> Transition_frontier.Breadcrumb.consensus_state
          |> Consensus.Data.Consensus_state.blockchain_length )
        + 290 + slack
        < Length.to_int
            (Consensus.Data.Consensus_state.blockchain_length
               new_consensus_state.data )
      then (* Then our entire frontier is useless. *)
        true
      else
        let module Context = struct
          include Context

          let logger =
            Logger.extend logger
              [ ( "selection_context"
                , `String "Transition_router.is_transition_for_bootstrap" )
              ]
        end in
        Consensus.Hooks.should_bootstrap
          ~context:(module Context)
          ~existing:root_consensus_state ~candidate:new_consensus_state

let start_transition_frontier_controller ~context:(module Context : CONTEXT)
    ~trust_system ~verifier ~network ~time_controller
    ~producer_transition_writer_ref ~verified_transition_writer ~clear_reader
    ~collected_transitions ?transition_writer_ref ~frontier_w frontier =
  let open Context in
  [%str_log info] Starting_transition_frontier_controller ;
  let ( transition_frontier_controller_reader
      , transition_frontier_controller_writer ) =
    let name = "transition frontier controller pipe" in
    create_bufferred_pipe ~name
      ~f:(fun (`Block block, `Valid_cb valid_cb) ->
        Mina_metrics.(
          Counter.inc_one
            Pipe.Drop_on_overflow.router_transition_frontier_controller) ;
        Mina_block.handle_dropped_transition
          ( With_hash.hash @@ Validation.block_with_hash
          @@ Network_peer.Envelope.Incoming.data block )
          ?valid_cb ~pipe_name:name ~logger )
      ()
  in
  let transition_writer_ref =
    Option.value transition_writer_ref
      ~default:(ref transition_frontier_controller_writer)
  in
  transition_writer_ref := transition_frontier_controller_writer ;
  let producer_transition_reader, producer_transition_writer =
    Strict_pipe.create ~name:"transition frontier: producer transition"
      Synchronous
  in
  producer_transition_writer_ref := Some producer_transition_writer ;
  Broadcast_pipe.Writer.write frontier_w (Some frontier) |> don't_wait_for ;
  Transition_frontier_controller.run
    ~context:(module Context)
    ~trust_system ~verifier ~network ~time_controller ~collected_transitions
    ~frontier ~network_transition_reader:transition_frontier_controller_reader
    ~producer_transition_reader ~clear_reader ~verified_transition_writer ;
  transition_writer_ref

let start_bootstrap_controller ~context:(module Context : CONTEXT) ~trust_system
    ~verifier ~network ~time_controller ~producer_transition_writer_ref
    ~verified_transition_writer ~clear_reader ?transition_writer_ref
    ~consensus_local_state ~frontier_w ~initial_root_transition ~persistent_root
    ~persistent_frontier ~best_seen_transition ~catchup_mode =
  let open Context in
  [%str_log info] Starting_bootstrap_controller ;
  [%log info] "Starting Bootstrap Controller phase" ;
  let bootstrap_controller_reader, bootstrap_controller_writer =
    let name = "bootstrap controller pipe" in
    create_bufferred_pipe ~name
      ~f:(fun (`Block head, `Valid_cb valid_cb) ->
        Mina_metrics.(
          Counter.inc_one Pipe.Drop_on_overflow.router_bootstrap_controller) ;
        Mina_block.handle_dropped_transition
          ( With_hash.hash @@ Validation.block_with_hash
          @@ Network_peer.Envelope.Incoming.data head )
          ~pipe_name:name ~logger ?valid_cb )
      ()
  in
  let transition_writer_ref =
    Option.value transition_writer_ref
      ~default:(ref bootstrap_controller_writer)
  in
  transition_writer_ref := bootstrap_controller_writer ;
  producer_transition_writer_ref := None ;
  let f block =
    Strict_pipe.Writer.write bootstrap_controller_writer
      (`Block block, `Valid_cb None) ;
    match Envelope.Incoming.sender block with Remote r -> [ r ] | Local -> []
  in
  let preferred_peers = Option.value_map ~f ~default:[] best_seen_transition in
  don't_wait_for (Broadcast_pipe.Writer.write frontier_w None) ;
  upon
    (Bootstrap_controller.run
       ~context:(module Context)
       ~trust_system ~verifier ~network ~consensus_local_state
       ~transition_reader:bootstrap_controller_reader ~persistent_frontier
       ~persistent_root ~initial_root_transition ~preferred_peers ~catchup_mode )
    (fun (new_frontier, collected_transitions) ->
      Strict_pipe.Writer.kill bootstrap_controller_writer ;
      start_transition_frontier_controller
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller
        ~producer_transition_writer_ref ~verified_transition_writer
        ~clear_reader ~collected_transitions ~transition_writer_ref ~frontier_w
        new_frontier
      |> Fn.const () ) ;
  transition_writer_ref

let download_best_tip ~context:(module Context : CONTEXT) ~notify_online
    ~network ~verifier ~trust_system ~most_recent_valid_block_writer
    ~genesis_constants =
  let open Context in
  let num_peers = 16 in
  let%bind peers = Mina_networking.random_peers network num_peers in
  [%log info] "Requesting peers for their best tip to do initialization" ;
  let%bind tips =
    Deferred.List.filter_map ~how:`Parallel peers ~f:(fun peer ->
        let open Deferred.Let_syntax in
        match%bind
          Mina_networking.get_best_tip
            ~heartbeat_timeout:(Time_ns.Span.of_min 1.)
            ~timeout:(Time.Span.of_min 1.) network peer
        with
        | Error e ->
            [%log debug]
              ~metadata:
                [ ("peer", Network_peer.Peer.to_yojson peer)
                ; ("error", Error_json.error_to_yojson e)
                ]
              "Couldn't get best tip from peer: $error" ;
            return None
        | Ok peer_best_tip -> (
            [%log debug]
              ~metadata:
                [ ("peer", Network_peer.Peer.to_yojson peer)
                ; ( "length"
                  , Length.to_yojson
                      (Mina_block.blockchain_length peer_best_tip.data) )
                ]
              "Successfully downloaded best tip with $length from $peer" ;
            (* TODO: Use batch verification instead *)
            match%bind
              Best_tip_prover.verify ~verifier peer_best_tip ~genesis_constants
                ~precomputed_values
            with
            | Error e ->
                [%log warn]
                  ~metadata:
                    [ ("peer", Network_peer.Peer.to_yojson peer)
                    ; ("error", Error_json.error_to_yojson e)
                    ]
                  "Peer sent us bad proof for their best tip" ;
                let%map () =
                  Trust_system.(
                    record trust_system logger peer
                      Actions.
                        ( Violated_protocol
                        , Some ("Peer sent us bad proof for their best tip", [])
                        ))
                in
                None
            | Ok (`Root _, `Best_tip candidate_best_tip) ->
                [%log debug]
                  ~metadata:[ ("peer", Network_peer.Peer.to_yojson peer) ]
                  "Successfully verified best tip from $peer" ;
                return
                  (Some
                     (Envelope.Incoming.wrap_peer
                        ~data:{ peer_best_tip with data = candidate_best_tip }
                        ~sender:peer ) ) ) )
  in
  [%log debug]
    ~metadata:
      [ ("actual", `Int (List.length tips)); ("expected", `Int num_peers) ]
    "Finished requesting tips. Got $actual / $expected" ;
  let%map () = notify_online () in
  let res =
    List.fold tips ~init:None ~f:(fun acc enveloped_candidate_best_tip ->
        Option.merge acc (Option.return enveloped_candidate_best_tip)
          ~f:(fun enveloped_existing_best_tip enveloped_candidate_best_tip ->
            let f x =
              Validation.block_with_hash x
              |> With_hash.map ~f:Mina_block.consensus_state
            in
            match
              Consensus.Hooks.select
                ~context:(module Context)
                ~existing:(f enveloped_existing_best_tip.data.data)
                ~candidate:(f enveloped_candidate_best_tip.data.data)
            with
            | `Keep ->
                enveloped_existing_best_tip
            | `Take ->
                enveloped_candidate_best_tip ) )
  in
  Option.iter res ~f:(fun best ->
      let best_tip_length =
        Validation.block best.data.data
        |> Mina_block.blockchain_length |> Length.to_int
      in
      Mina_metrics.Transition_frontier.update_max_blocklength_observed
        best_tip_length ;
      don't_wait_for
      @@ Broadcast_pipe.Writer.write most_recent_valid_block_writer
           best.data.data ) ;
  Option.map res
    ~f:
      (Envelope.Incoming.map ~f:(fun (x : _ Proof_carrying_data.t) ->
           Ledger_catchup.Best_tip_lru.add x ;
           x.data ) )

let load_frontier ~context:(module Context : CONTEXT) ~verifier
    ~persistent_frontier ~persistent_root ~consensus_local_state ~catchup_mode =
  let open Context in
  match%map
    Transition_frontier.load
      ~context:(module Context)
      ~verifier ~consensus_local_state ~persistent_root ~persistent_frontier
      ~catchup_mode ()
  with
  | Ok frontier ->
      [%log info] "Successfully loaded frontier" ;
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
  | Error `Snarked_ledger_mismatch ->
      [%log warn] "Persistent database is out of sync with snarked_ledger" ;
      None

let wait_for_high_connectivity ~logger ~network ~is_seed =
  let connectivity_time_upperbound = 60.0 in
  let high_connectivity =
    Mina_networking.on_first_high_connectivity network ~f:Fn.id
  in
  Deferred.any
    [ ( high_connectivity
      >>| fun () ->
      [%log info] "Already connected to enough peers, start initialization" )
    ; ( after (Time_ns.Span.of_sec connectivity_time_upperbound)
      >>= fun () ->
      Mina_networking.peers network
      >>| fun peers ->
      if not @@ Deferred.is_determined high_connectivity then
        if List.length peers = 0 then
          if is_seed then
            [%log info]
              ~metadata:
                [ ( "max seconds to wait for high connectivity"
                  , `Float connectivity_time_upperbound )
                ]
              "Will start initialization without connecting to any peers"
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
                , `Float connectivity_time_upperbound )
              ]
            "Will start initialization without connecting to too many peers" )
    ]

let initialize ~context:(module Context : CONTEXT) ~network ~is_seed
    ~is_demo_mode ~verifier ~trust_system ~time_controller ~frontier_w
    ~producer_transition_writer_ref ~clear_reader ~verified_transition_writer
    ~most_recent_valid_block_writer ~persistent_root ~persistent_frontier
    ~consensus_local_state ~catchup_mode ~notify_online =
  let open Context in
  let%bind () =
    if is_demo_mode then return ()
    else wait_for_high_connectivity ~logger ~network ~is_seed
  in
  let genesis_constants =
    Precomputed_values.genesis_constants precomputed_values
  in
  match%bind
    Deferred.both
      (download_best_tip
         ~context:(module Context)
         ~notify_online ~network ~verifier ~trust_system
         ~most_recent_valid_block_writer ~genesis_constants )
      (load_frontier
         ~context:(module Context)
         ~verifier ~persistent_frontier ~persistent_root ~consensus_local_state
         ~catchup_mode )
  with
  | best_seen_transition, None ->
      [%log info] "Unable to load frontier; starting bootstrap" ;
      let%map initial_root_transition =
        Persistent_frontier.(
          with_instance_exn persistent_frontier ~f:Instance.get_root_transition)
        >>| Result.ok_or_failwith
      in
      start_bootstrap_controller
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller
        ~producer_transition_writer_ref ~verified_transition_writer
        ~clear_reader ?transition_writer_ref:None ~consensus_local_state
        ~frontier_w ~persistent_root ~persistent_frontier
        ~initial_root_transition ~catchup_mode ~best_seen_transition
  | Some best_tip, Some frontier
    when is_transition_for_bootstrap
           ~context:(module Context)
           frontier
           (best_tip |> Envelope.Incoming.data) ->
      [%log info]
        ~metadata:
          [ ( "length"
            , `Int
                (Unsigned.UInt32.to_int
                   ( Mina_block.blockchain_length
                   @@ Validation.block best_tip.data ) ) )
          ]
        "Network best tip is too new to catchup to (best_tip with $length); \
         starting bootstrap" ;
      let initial_root_transition =
        Transition_frontier.(Breadcrumb.validated_transition (root frontier))
      in
      let%map () = Transition_frontier.close ~loc:__LOC__ frontier in
      start_bootstrap_controller
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller
        ~producer_transition_writer_ref ~verified_transition_writer
        ~clear_reader ?transition_writer_ref:None ~consensus_local_state
        ~frontier_w ~persistent_root ~persistent_frontier
        ~initial_root_transition ~catchup_mode
        ~best_seen_transition:(Some best_tip)
  | best_tip_opt, Some frontier ->
      let collected_transitions =
        match best_tip_opt with
        | Some best_tip ->
            [%log info]
              ~metadata:
                [ ( "length"
                  , `Int
                      (Unsigned.UInt32.to_int
                         ( Mina_block.blockchain_length
                         @@ Validation.block best_tip.data ) ) )
                ]
              "Network best tip is recent enough to catchup to (best_tip with \
               $length); syncing local state and starting participation" ;
            let f x = Bootstrap_controller.Transition_cache.Block x in
            [ (Envelope.Incoming.map ~f best_tip, None) ]
        | None ->
            [%log info]
              "Successfully loaded frontier, but failed downloaded best tip \
               from network" ;
            []
      in
      let curr_best_tip = Transition_frontier.best_tip frontier in
      let%map () =
        match
          Consensus.Hooks.required_local_state_sync
            ~constants:precomputed_values.consensus_constants
            ~consensus_state:
              (Transition_frontier.Breadcrumb.consensus_state curr_best_tip)
            ~local_state:consensus_local_state
        with
        | None ->
            [%log info] "Local state already in sync" ;
            Deferred.unit
        | Some sync_jobs -> (
            [%log info] "Local state is out of sync; " ;
            match%map
              Consensus.Hooks.sync_local_state
                ~local_state:consensus_local_state
                ~context:(module Context)
                ~trust_system
                ~random_peers:(Mina_networking.random_peers network)
                ~query_peer:
                  { Consensus.Hooks.Rpcs.query =
                      (fun peer rpc query ->
                        Mina_networking.(
                          query_peer network peer.peer_id
                            (Rpcs.Consensus_rpc rpc) query) )
                  }
                sync_jobs
            with
            | Error e ->
                Error.tag e ~tag:"Local state sync failed" |> Error.raise
            | Ok () ->
                () )
      in
      start_transition_frontier_controller
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller
        ~producer_transition_writer_ref ~verified_transition_writer
        ~clear_reader ~collected_transitions ?transition_writer_ref:None
        ~frontier_w frontier

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
          , `Int (Int64.to_int_exn (Time.Span.to_ms time_till_genesis)) )
        ]
      "Node started before the chain start time: waiting $time_till_genesis \
       milliseconds before starting participation" ;
    let rec logger_loop () =
      let%bind () = after (Time_ns.Span.of_sec 30.) in
      let now = Time.now time_controller in
      try
        Consensus.Hooks.is_genesis_epoch ~constants:consensus_constants now
        |> Fn.const Deferred.unit
      with Invalid_argument _ ->
        let tm_remaining = Time.diff genesis_state_timestamp now in
        [%log debug]
          "Time before the chain start time. Waiting $tm_remaining \
           milliseconds before starting participation"
          ~metadata:
            [ ( "tm_remaining"
              , `Int (Int64.to_int_exn @@ Time.Span.to_ms tm_remaining) )
            ] ;
        logger_loop ()
    in
    Time.Timeout.await ~timeout_duration:time_till_genesis time_controller
      (logger_loop ())
    |> Deferred.ignore_m

let run ~context:(module Context : CONTEXT) ~trust_system ~verifier ~network
    ~is_seed ~is_demo_mode ~time_controller ~consensus_local_state
    ~persistent_root_location ~persistent_frontier_location
    ~frontier_broadcast_pipe:(frontier_r, frontier_w) ~network_transition_reader
    ~producer_transition_reader
    ~most_recent_valid_block:
      (most_recent_valid_block_reader, most_recent_valid_block_writer)
    ~catchup_mode ~notify_online =
  let open Context in
  let initialization_finish_signal = Ivar.create () in
  let clear_reader, clear_writer =
    Strict_pipe.create ~name:"clear" Synchronous
  in
  let verified_transition_reader, verified_transition_writer =
    let name = "verified transitions" in
    create_bufferred_pipe ~name
      ~f:(fun ( `Transition (head : Mina_block.Validated.t)
              , _
              , `Valid_cb valid_cb ) ->
        Mina_metrics.(
          Counter.inc_one Pipe.Drop_on_overflow.router_verified_transitions) ;
        Mina_block.handle_dropped_transition
          (Mina_block.Validated.forget head |> With_hash.hash)
          ~pipe_name:name ~logger ?valid_cb )
      ()
  in
  (* Ref is None when bootstrap is in progress and Some writer when it's catch-up.query
     In fact, we don't expect any produced blocks during bootstrap (possible only in rare case
     of race condition between bootstrap and block creation) *)
  let producer_transition_writer_ref = ref None in
  O1trace.background_thread "transition_router" (fun () ->
      don't_wait_for
      @@ Strict_pipe.Reader.iter producer_transition_reader ~f:(fun x ->
             Option.value_map ~f:Strict_pipe.Writer.write
               ~default:(Fn.const Deferred.unit)
               !producer_transition_writer_ref
               x ) ;
      let%bind () =
        wait_till_genesis ~logger ~time_controller ~precomputed_values
      in
      let valid_transition_reader, valid_transition_writer =
        let name = "valid transitions" in
        create_bufferred_pipe ~name
          ~f:(fun head ->
            let `Block block, `Valid_cb valid_cb = head in
            Mina_metrics.(
              Counter.inc_one Pipe.Drop_on_overflow.router_valid_transitions) ;
            Mina_block.handle_dropped_transition
              ( Network_peer.Envelope.Incoming.data block
              |> Validation.block_with_hash |> With_hash.hash )
              ~valid_cb ~pipe_name:name ~logger )
          ()
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
      let%map transition_writer_ref =
        initialize
          ~context:(module Context)
          ~network ~is_seed ~is_demo_mode ~verifier ~trust_system
          ~persistent_frontier ~persistent_root ~time_controller ~frontier_w
          ~catchup_mode ~producer_transition_writer_ref ~clear_reader
          ~verified_transition_writer ~most_recent_valid_block_writer
          ~consensus_local_state ~notify_online
      in
      Ivar.fill_if_empty initialization_finish_signal () ;
      let valid_transition_reader1, valid_transition_reader2 =
        Strict_pipe.Reader.Fork.two valid_transition_reader
      in
      don't_wait_for
      @@ Strict_pipe.Reader.iter valid_transition_reader1
           ~f:(fun (`Block enveloped_transition, _) ->
             let incoming_transition =
               Envelope.Incoming.data enveloped_transition
             in
             let current_transition =
               Broadcast_pipe.Reader.peek most_recent_valid_block_reader
             in
             if
               Consensus.Hooks.equal_select_status `Take
                 (Consensus.Hooks.select
                    ~context:(module Context)
                    ~existing:
                      ( Validation.block_with_hash current_transition
                      |> With_hash.map ~f:Mina_block.consensus_state )
                    ~candidate:
                      ( Validation.block_with_hash incoming_transition
                      |> With_hash.map ~f:Mina_block.consensus_state ) )
             then
               (* TODO: do we need to push valid_cb? *)
               Broadcast_pipe.Writer.write most_recent_valid_block_writer
                 incoming_transition
             else Deferred.unit ) ;
      don't_wait_for
      @@ Strict_pipe.Reader.iter_without_pushback valid_transition_reader2
           ~f:(fun (`Block enveloped_transition, `Valid_cb vc) ->
             don't_wait_for
             @@ let%map () =
                  let incoming_transition =
                    Envelope.Incoming.data enveloped_transition
                  in
                  match Broadcast_pipe.Reader.peek frontier_r with
                  | Some frontier ->
                      if
                        is_transition_for_bootstrap
                          ~context:(module Context)
                          frontier incoming_transition
                      then (
                        Strict_pipe.Writer.kill !transition_writer_ref ;
                        Option.iter ~f:Strict_pipe.Writer.kill
                          !producer_transition_writer_ref ;
                        let initial_root_transition =
                          Transition_frontier.(
                            Breadcrumb.validated_transition (root frontier))
                        in
                        let%bind () =
                          Strict_pipe.Writer.write clear_writer `Clear
                        in
                        let%map () =
                          Transition_frontier.close ~loc:__LOC__ frontier
                        in
                        Fn.const ()
                        @@ start_bootstrap_controller
                             ~context:(module Context)
                             ~trust_system ~verifier ~network ~time_controller
                             ~producer_transition_writer_ref
                             ~verified_transition_writer ~clear_reader
                             ~transition_writer_ref ~consensus_local_state
                             ~frontier_w ~persistent_root ~persistent_frontier
                             ~initial_root_transition
                             ~best_seen_transition:(Some enveloped_transition)
                             ~catchup_mode )
                      else Deferred.unit
                  | None ->
                      Deferred.unit
                in
                Strict_pipe.Writer.write !transition_writer_ref
                  (`Block enveloped_transition, `Valid_cb (Some vc)) ) ) ;
  (verified_transition_reader, initialization_finish_signal)
