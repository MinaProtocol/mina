open Core_kernel
open Async_kernel
open Pipe_lib
open Network_peer
open Mina_numbers

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val ledger_sync_config : Syncable_ledger.daemon_config

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

type Structured_log_events.t += Starting_transition_frontier_controller
  [@@deriving
    register_event { msg = "Starting transition frontier controller phase" }]

type Structured_log_events.t += Starting_bootstrap_controller
  [@@deriving register_event { msg = "Starting bootstrap controller phase" }]

let create_buffered_pipe ?name ~f () =
  Strict_pipe.create ?name (Buffered (`Capacity 50, `Overflow (Drop_head f)))

let block_or_header_to_header_hashed b_or_h =
  match b_or_h with
  | `Block b ->
      With_hash.map ~f:Mina_block.header @@ fst @@ Envelope.Incoming.data b
  | `Header h ->
      fst @@ Envelope.Incoming.data h

let block_or_header_to_header_hashed_with_validation b_or_h =
  match b_or_h with
  | `Block b ->
      let b', v = Envelope.Incoming.data b in
      (With_hash.map ~f:Mina_block.header b', v)
  | `Header h ->
      Envelope.Incoming.data h

let block_or_header_to_hash
    (b_or_h :
      [ `Block of
        Mina_block.Validation.initial_valid_with_block Envelope.Incoming.t
      | `Header of
        Mina_block.Validation.initial_valid_with_header Envelope.Incoming.t ] )
    =
  With_hash.hash (block_or_header_to_header_hashed b_or_h)

let to_consensus_state h =
  Mina_block.Validation.header_with_hash h
  |> With_hash.map
       ~f:
         (Fn.compose Mina_state.Protocol_state.consensus_state
            Mina_block.Header.protocol_state )

let is_transition_for_bootstrap
    ~context:(module Context : Consensus.Intf.CONTEXT) frontier new_header =
  let root_consensus_state =
    Transition_frontier.root frontier
    |> Transition_frontier.Breadcrumb.consensus_state_with_hashes
  in
  let new_consensus_state = to_consensus_state new_header in
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

let start_transition_frontier_controller ?transaction_pool_proxy
    ~context:(module Context : CONTEXT) ~trust_system ~verifier ~network
    ~time_controller ~get_completed_work ~producer_transition_writer_ref
    ~verified_transition_writer ~clear_reader ~collected_transitions
    ~cache_exceptions ~network_transition_pipe ~frontier_w frontier =
  let open Context in
  [%str_log info] Starting_transition_frontier_controller ;
  let producer_transition_reader, producer_transition_writer =
    Strict_pipe.create ~name:"transition frontier: producer transition"
      Synchronous
  in
  (* No block production happens when bootstrap is running. The
     [producer_transition_writer_ref] pipe was created just to substitute a
     value for the type and was never actually used. It could have been read
     only by the transition frontier controller, and it's not running when
     bootstrap controller is active *)
  producer_transition_writer_ref := Some producer_transition_writer ;
  Broadcast_pipe.Writer.write frontier_w (Some frontier) |> don't_wait_for ;
  let start_and_iterate =
    let%bind transition_frontier_controller_reader =
      Strict_pipe.Swappable.swap_reader network_transition_pipe
    in
    let new_verified_transition_reader =
      Transition_frontier_controller.run ?transaction_pool_proxy
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller ~collected_transitions
        ~frontier ~get_completed_work
        ~network_transition_reader:transition_frontier_controller_reader
        ~producer_transition_reader ~clear_reader ~cache_exceptions
    in
    Strict_pipe.Reader.iter new_verified_transition_reader
      ~f:
        (Fn.compose Deferred.return
           (Strict_pipe.Writer.write verified_transition_writer) )
  in
  don't_wait_for start_and_iterate

let start_bootstrap_controller ~context:(module Context : CONTEXT) ~trust_system
    ~verifier ~network ~time_controller ~get_completed_work
    ~producer_transition_writer_ref ~verified_transition_writer ~clear_reader
    ~network_transition_pipe ~consensus_local_state ~frontier_w
    ~initial_root_transition ~persistent_root ~persistent_frontier
    ~cache_exceptions ~best_seen_transition ~catchup_mode =
  let open Context in
  [%str_log info] Starting_bootstrap_controller ;
  producer_transition_writer_ref := None ;
  let f b_or_h =
    Strict_pipe.Swappable.write network_transition_pipe (b_or_h, `Valid_cb None) ;
    let sender =
      match b_or_h with
      | `Block b ->
          Envelope.Incoming.sender b
      | `Header h ->
          Envelope.Incoming.sender h
    in
    match sender with Remote r -> [ r ] | Local -> []
  in
  let preferred_peers = Option.value_map ~f ~default:[] best_seen_transition in
  don't_wait_for (Broadcast_pipe.Writer.write frontier_w None) ;

  upon
    (Bootstrap_controller.run
       ~context:(module Context)
       ~trust_system ~verifier ~network ~consensus_local_state
       ~network_transition_pipe ~persistent_frontier ~persistent_root
       ~initial_root_transition ~preferred_peers ~catchup_mode )
    (fun (new_frontier, collected_transitions) ->
      start_transition_frontier_controller
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller ~get_completed_work
        ~producer_transition_writer_ref ~verified_transition_writer
        ~clear_reader ~collected_transitions ~cache_exceptions
        ~network_transition_pipe ~frontier_w new_frontier )
  |> Fn.const ()

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
                      ( Mina_block.Stable.Latest.header peer_best_tip.data
                      |> Mina_block.Header.blockchain_length ) )
                ]
              "Successfully downloaded best tip with $length from $peer" ;
            (* TODO: Use batch verification instead *)
            match%bind
              Best_tip_prover.verify ~verifier ~genesis_constants
                ~precomputed_values
              @@ Mina_block.Proof_carrying.to_header_data
                   ~to_header:Mina_block.Stable.Latest.header peer_best_tip
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
                let body =
                  Mina_block.Stable.Latest.body peer_best_tip.data
                  |> Staged_ledger_diff.Body.write_all_proofs_to_disk
                       ~signature_kind ~proof_cache_db
                in
                return
                  (Some
                     (Envelope.Incoming.wrap_peer
                        ~data:
                          { peer_best_tip with
                            data =
                              Mina_block.Validation.with_body candidate_best_tip
                                body
                          }
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
              Mina_block.Validation.block_with_hash x
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
      let best_tip = best.data.data in
      let best_tip_length =
        Mina_block.Validation.block best_tip
        |> Mina_block.blockchain_length |> Length.to_int
      in
      Mina_metrics.Transition_frontier.update_max_blocklength_observed
        best_tip_length ;
      don't_wait_for
      @@ Broadcast_pipe.Writer.write most_recent_valid_block_writer
      @@ Mina_block.Validation.to_header best_tip ) ;
  Option.map res
    ~f:
      (Envelope.Incoming.map
         ~f:(fun { Proof_carrying_data.data; proof = path, root } ->
           Ledger_catchup.Best_tip_lru.add
             { Proof_carrying_data.data =
                 Mina_block.Validation.block_with_hash data
                 |> Mina_base.State_hash.With_state_hashes.state_hash
             ; proof = (path, Mina_block.Stable.Latest.header root)
             } ;
           data ) )

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
  if is_seed then (
    [%log info]
      "We are seed, not waiting for peers to show up, start initialization" ;
    Deferred.unit )
  else
    let connectivity_time_upperbound = 60.0 in
    let high_connectivity =
      Mina_networking.on_first_high_connectivity network ~f:Fn.id
    in
    match%bind
      Timeout_lib.Core_time_ns.await
        ~timeout_duration:(Time_ns.Span.of_sec connectivity_time_upperbound)
        () high_connectivity
    with
    | `Ok () ->
        [%log info] "Already connected to enough peers, start initialization" ;
        Deferred.unit
    | `Timeout ->
        let%bind peers = Mina_networking.peers network in
        if List.is_empty peers then (
          [%log error]
            "Failed to find any peers during initialization (crashing because \
             this is not a seed node)" ;
          exit 1 )
        else (
          [%log warn]
            ~metadata:
              [ ("num peers", `Int (List.length peers))
              ; ( "max seconds to wait for high connectivity"
                , `Float connectivity_time_upperbound )
              ]
            "Will start initialization without connecting to too many peers" ;
          Deferred.unit )

let best_tip_metadata best_tip =
  [ ( "length"
    , `Int
        (Unsigned.UInt32.to_int
           ( Mina_block.blockchain_length
           @@ Mina_block.Validation.block best_tip.Envelope.Incoming.data ) ) )
  ]

let log_recent_best_tip ~logger ~local_sync_resolution ~ready_for_catchup
    best_tip =
  let state =
    if ready_for_catchup then "recent enough for catchup" else "downloaded"
  in
  [%log info]
    ~metadata:(best_tip_metadata best_tip)
    "Network best tip is %s (best_tip with $length); %s" state
    local_sync_resolution

let log_recent_best_tip_opt ~logger ?(ready_for_catchup = true) ?best_tip
    local_sync_resolution =
  match best_tip with
  | Some best_tip ->
      log_recent_best_tip ~logger ~ready_for_catchup ~local_sync_resolution
        best_tip
  | None ->
      [%log info]
        "Successfully loaded frontier, but failed to download best tip from \
         network"

let collected_transition_of_best_tip best_tip =
  (Envelope.Incoming.map ~f:(fun x -> `Block x) best_tip, None)

let collected_transitions_of_best_tip best_tip_opt =
  match best_tip_opt with
  | Some best_tip ->
      [ collected_transition_of_best_tip best_tip ]
  | None ->
      []

let initialize_with_existing_frontier ~context:(module Context : CONTEXT)
    ~start_catchup ~frontier ~required_local_state_sync ~sync_local_state
    ~close_frontier_and_start_bootstrap ~download_best_tip best_tip_opt =
  let handle_successful_local_state_sync ~collected_transitions ~resolved result
      =
    Ivar.fill_if_empty resolved true ;
    Or_error.tag ~tag:"local state sync failed" result |> Or_error.ok_exn ;
    `Finished (`Catchup collected_transitions)
  in
  let handle_best_tip collected_transitions = function
    | Some best_tip
      when is_transition_for_bootstrap
             ~context:(module Context)
             frontier
             ( best_tip |> Envelope.Incoming.data
             |> Mina_block.Validation.to_header ) ->
        `Finished (`Bootstrap best_tip)
    | None ->
        `Repeat collected_transitions
    | Some best_tip ->
        log_recent_best_tip ~logger:Context.logger
          ~local_sync_resolution:"sync is in progress" ~ready_for_catchup:false
          best_tip ;
        `Repeat
          (collected_transition_of_best_tip best_tip :: collected_transitions)
  in
  let local_state_sync_iter sync_job_deferred collected_transitions =
    let resolved = Ivar.create () in
    upon
      (after (Time_ns.Span.of_min 5.))
      (fun () -> Ivar.fill_if_empty resolved false) ;
    (* TODO listen to block/header gossips and switch too *)
    Deferred.choose
      [ Deferred.choice sync_job_deferred
          (handle_successful_local_state_sync ~resolved ~collected_transitions)
      ; Deferred.choice
          ( Ivar.read resolved
          >>= function
          | true -> Deferred.return None | _ -> download_best_tip () )
          (handle_best_tip collected_transitions)
      ]
  in
  let local_state_sync_loop sync_job_deferred collected_transitions =
    Deferred.repeat_until_finished collected_transitions
      (local_state_sync_iter sync_job_deferred)
  in
  let open Context in
  match required_local_state_sync (Transition_frontier.best_tip frontier) with
  | None ->
      log_recent_best_tip_opt ~logger ?best_tip:best_tip_opt
        "local state already in sync" ;
      let%map () = Deferred.unit in
      start_catchup frontier @@ collected_transitions_of_best_tip best_tip_opt
  | Some sync_jobs -> (
      log_recent_best_tip_opt ~logger ~ready_for_catchup:false
        ?best_tip:best_tip_opt "starting local sync" ;
      local_state_sync_loop
        (sync_local_state sync_jobs)
        (collected_transitions_of_best_tip best_tip_opt)
      >>= function
      | `Bootstrap best_tip ->
          close_frontier_and_start_bootstrap best_tip frontier
      | `Catchup collected_transitions ->
          let%map () = Deferred.unit in
          start_catchup frontier collected_transitions )

let initialize ~transaction_pool_proxy ~context:(module Context : CONTEXT)
    ~sync_local_state ~network ~is_seed ~is_demo_mode ~verifier ~trust_system
    ~time_controller ~get_completed_work ~frontier_w
    ~producer_transition_writer_ref ~clear_reader ~verified_transition_writer
    ~cache_exceptions ~most_recent_valid_block_writer ~persistent_root
    ~persistent_frontier ~consensus_local_state ~catchup_mode ~notify_online
    ~network_transition_pipe =
  let open Context in
  [%log info] "Initializing transition router" ;
  let%bind () =
    if is_demo_mode then return ()
    else wait_for_high_connectivity ~logger ~network ~is_seed
  in
  let genesis_constants =
    Precomputed_values.genesis_constants precomputed_values
  in
  let start_bootstrap initial_root_transition best_seen_transition =
    start_bootstrap_controller
      ~context:(module Context)
      ~trust_system ~verifier ~network ~time_controller ~get_completed_work
      ~producer_transition_writer_ref ~verified_transition_writer ~clear_reader
      ~network_transition_pipe ~consensus_local_state ~frontier_w
      ~persistent_root ~persistent_frontier ~cache_exceptions
      ~initial_root_transition ~catchup_mode ~best_seen_transition
  in
  let load_initial_root_transition_from_persistence () =
    Persistent_frontier.(
      with_instance_exn persistent_frontier
        ~f:(Instance.get_root_transition ~signature_kind ~proof_cache_db))
    >>| Result.ok_or_failwith
  in
  let start_catchup frontier collected_transitions =
    start_transition_frontier_controller ?transaction_pool_proxy
      ~context:(module Context)
      ~trust_system ~verifier ~network ~time_controller ~get_completed_work
      ~producer_transition_writer_ref ~verified_transition_writer ~clear_reader
      ~collected_transitions ~cache_exceptions ~network_transition_pipe
      ~frontier_w frontier
  in
  let close_frontier_and_start_bootstrap best_tip frontier =
    [%log info]
      ~metadata:(best_tip_metadata best_tip)
      "Network best tip is too new to catchup to (best_tip with $length); \
       starting bootstrap" ;
    let initial_root_transition =
      Transition_frontier.(Breadcrumb.validated_transition (root frontier))
    in
    let%map () = Transition_frontier.close ~loc:__LOC__ frontier in
    start_bootstrap initial_root_transition (Some (`Block best_tip))
  in
  let required_local_state_sync transition =
    Consensus.Hooks.required_local_state_sync
      ~constants:precomputed_values.consensus_constants
      ~consensus_state:
        (Transition_frontier.Breadcrumb.consensus_state transition)
      ~local_state:consensus_local_state
  in
  let sync_local_state_do =
    Consensus.Hooks.sync_local_state ~local_state:consensus_local_state
      ~glue_sync_ledger:(Mina_networking.glue_sync_ledger network)
      ~context:(module Context)
      ~trust_system
  in
  let download_best_tip () =
    download_best_tip
      ~context:(module Context)
      ~notify_online ~network ~verifier ~trust_system
      ~most_recent_valid_block_writer ~genesis_constants
  in
  let%bind best_tip_opt = download_best_tip ()
  and frontier_opt =
    load_frontier
      ~context:(module Context)
      ~verifier ~persistent_frontier ~persistent_root ~consensus_local_state
      ~catchup_mode
  in
  match (best_tip_opt, frontier_opt) with
  | best_seen_transition, None ->
      let download_status_str, metadata =
        match best_seen_transition with
        | Some best_tip ->
            ("downloaded", best_tip_metadata best_tip)
        | None ->
            ("failed to download", [])
      in
      [%log info] "Unable to load frontier; starting bootstrap, best tip %s"
        download_status_str ~metadata ;
      let%map initial_root_transition =
        load_initial_root_transition_from_persistence ()
      in
      start_bootstrap initial_root_transition
        (Option.map ~f:(fun x -> `Block x) best_seen_transition)
  | Some best_tip, Some frontier
    when is_transition_for_bootstrap
           ~context:(module Context)
           frontier
           ( best_tip |> Envelope.Incoming.data
           |> Mina_block.Validation.to_header ) ->
      close_frontier_and_start_bootstrap best_tip frontier
  | best_tip_opt, Some frontier when not sync_local_state ->
      log_recent_best_tip_opt ~logger ?best_tip:best_tip_opt
        "not syncing local state, should only occur in tests" ;
      (* make frontier available for tests *)
      let%map () = Broadcast_pipe.Writer.write frontier_w (Some frontier) in
      start_catchup frontier @@ collected_transitions_of_best_tip best_tip_opt
  | best_tip_opt, Some frontier ->
      initialize_with_existing_frontier
        ~context:(module Context)
        ~start_catchup ~frontier ~required_local_state_sync
        ~sync_local_state:sync_local_state_do best_tip_opt
        ~close_frontier_and_start_bootstrap ~download_best_tip

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

(* [sync_local_state] may be `false` for tests, where we want
   to set local state in the test
*)
let run ?(sync_local_state = true) ?(cache_exceptions = false)
    ?transaction_pool_proxy ~context:(module Context : CONTEXT) ~trust_system
    ~verifier ~network ~is_seed ~is_demo_mode ~time_controller
    ~consensus_local_state ~persistent_root_location
    ~persistent_frontier_location ~get_current_frontier
    ~frontier_broadcast_writer:frontier_w ~network_transition_reader
    ~producer_transition_reader ~get_most_recent_valid_block
    ~most_recent_valid_block_writer ~get_completed_work ~catchup_mode
    ~notify_online ~ledger_backing () =
  (* signature_kind is passed through to various callees *)
  let open Context in
  [%log info] "Starting transition router" ;
  let initialization_finish_signal = Ivar.create () in
  let clear_reader, clear_writer =
    Strict_pipe.create ~name:"clear" Synchronous
  in
  let verified_transition_reader, verified_transition_writer =
    let name = "verified transitions" in
    create_buffered_pipe ~name
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
  (* Ref is None when bootstrap is in progress and Some writer when it's catch-up.
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
        create_buffered_pipe ~name
          ~f:(fun head ->
            let b_or_h, `Valid_cb valid_cb = head in
            Mina_metrics.(
              Counter.inc_one Pipe.Drop_on_overflow.router_valid_transitions) ;
            Mina_block.handle_dropped_transition
              (block_or_header_to_hash b_or_h)
              ~valid_cb ~pipe_name:name ~logger )
          ()
      in
      let () =
        let initial_validate =
          unstage
            (Initial_validator.validate ~signature_kind ~proof_cache_db ~logger
               ~trust_system ~verifier ~initialization_finish_signal
               ~precomputed_values )
        in
        O1trace.background_thread "initially_validate_blocks" (fun () ->
            Pipe_lib.Strict_pipe.Reader.iter network_transition_reader
              ~f:(fun (b_or_h, `Time_received time_received, `Valid_cb valid_cb)
                 ->
                match%map initial_validate ~b_or_h ~time_received ~valid_cb with
                | Ok valid_transition ->
                    Pipe_lib.Strict_pipe.Writer.write valid_transition_writer
                      valid_transition
                | Error () ->
                    () ) )
      in
      let persistent_frontier =
        Transition_frontier.Persistent_frontier.create ~logger ~verifier
          ~time_controller ~directory:persistent_frontier_location
          ~signature_kind
      in
      let persistent_root =
        Transition_frontier.Persistent_root.create ~logger
          ~backing_type:ledger_backing ~directory:persistent_root_location
          ~ledger_depth:(Precomputed_values.ledger_depth precomputed_values)
      in
      let network_transition_pipe : _ Strict_pipe.Swappable.t =
        let name = "transition_frontier_controller_pipe" in
        let drop_f (b_or_h, `Valid_cb valid_cb) =
          Mina_metrics.(
            Counter.inc_one Pipe.Drop_on_overflow.router_transitions) ;
          Mina_block.handle_dropped_transition
            (block_or_header_to_hash b_or_h)
            ?valid_cb ~pipe_name:name ~logger
        in
        Strict_pipe.Swappable.create ~name
          (Buffered (`Capacity 50, `Overflow (Drop_head drop_f)))
      in
      let%map () =
        initialize ~transaction_pool_proxy ~sync_local_state ~cache_exceptions
          ~context:(module Context)
          ~network ~is_seed ~is_demo_mode ~verifier ~trust_system
          ~persistent_frontier ~persistent_root ~time_controller
          ~get_completed_work ~frontier_w ~catchup_mode
          ~producer_transition_writer_ref ~clear_reader
          ~verified_transition_writer ~most_recent_valid_block_writer
          ~consensus_local_state ~notify_online ~network_transition_pipe
      in

      Ivar.fill_if_empty initialization_finish_signal () ;

      let valid_transition_reader1, valid_transition_reader2 =
        Strict_pipe.Reader.Fork.two valid_transition_reader
      in
      don't_wait_for
      @@ Strict_pipe.Reader.iter valid_transition_reader1 ~f:(fun (b_or_h, _) ->
             let header_with_hash =
               block_or_header_to_header_hashed_with_validation b_or_h
             in
             let current_header_with_hash = get_most_recent_valid_block () in
             if
               Consensus.Hooks.equal_select_status `Take
                 (Consensus.Hooks.select
                    ~context:(module Context)
                    ~existing:(to_consensus_state current_header_with_hash)
                    ~candidate:(to_consensus_state header_with_hash) )
             then
               (* TODO: do we need to push valid_cb? *)
               Broadcast_pipe.Writer.write most_recent_valid_block_writer
                 header_with_hash
             else Deferred.unit ) ;
      don't_wait_for
      @@ Strict_pipe.Reader.iter_without_pushback valid_transition_reader2
           ~f:(fun (b_or_h, `Valid_cb vc) ->
             don't_wait_for
             @@ let%map () =
                  let header_with_hash =
                    block_or_header_to_header_hashed_with_validation b_or_h
                  in
                  match get_current_frontier () with
                  | Some frontier ->
                      if
                        is_transition_for_bootstrap
                          ~context:(module Context)
                          frontier header_with_hash
                      then (
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
                        ignore
                        @@ start_bootstrap_controller
                             ~context:(module Context)
                             ~trust_system ~verifier ~network ~time_controller
                             ~get_completed_work ~producer_transition_writer_ref
                             ~cache_exceptions ~verified_transition_writer
                             ~clear_reader ~network_transition_pipe
                             ~consensus_local_state ~frontier_w ~persistent_root
                             ~persistent_frontier ~initial_root_transition
                             ~best_seen_transition:(Some b_or_h) ~catchup_mode )
                      else Deferred.unit
                  | None ->
                      Deferred.unit
                in
                Strict_pipe.Swappable.write network_transition_pipe
                  (b_or_h, `Valid_cb (Some vc)) ) ) ;
  (verified_transition_reader, initialization_finish_signal)
