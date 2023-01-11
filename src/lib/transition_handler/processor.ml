(** This module contains the transition processor. The transition processor is
 *  the thread in which transitions are attached the to the transition frontier.
 *
 *  Two types of data are handled by the transition processor: validated external transitions
 *  with precomputed state hashes (via the block producer and validator pipes)
 *  and breadcrumb rose trees (via the catchup pipe).
 *)

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe
open Mina_base
open Mina_state
open Cache_lib
open Mina_block
open Network_peer

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

(* TODO: calculate a sensible value from postake consensus arguments *)
let catchup_timeout_duration (precomputed_values : Precomputed_values.t) =
  Block_time.Span.of_ms
    ( (precomputed_values.genesis_constants.protocol.delta + 1)
      * precomputed_values.constraint_constants.block_window_duration_ms
    |> Int64.of_int )
  |> Block_time.Span.min (Block_time.Span.of_ms (Int64.of_int 5000))

let cached_transform_deferred_result ~transform_cached ~transform_result cached
    =
  Cached.transform cached ~f:transform_cached
  |> Cached.sequence_deferred
  >>= Fn.compose transform_result Cached.sequence_result

let record_block_inclusion_time ~time_controller ~consensus_constants block =
  let transition_time =
    block |> Mina_block.Validated.header |> Mina_block.Header.protocol_state
    |> Protocol_state.consensus_state
    |> Consensus.Data.Consensus_state.consensus_time
  in
  let time_elapsed =
    Block_time.diff
      (Block_time.now time_controller)
      (Consensus.Data.Consensus_time.to_time ~constants:consensus_constants
         transition_time )
  in
  Mina_metrics.Block_latency.Inclusion_time.update
    (Block_time.Span.to_time_span time_elapsed)

type broadcast_actions =
  { broadcast : Mina_block.Validated.t -> unit
  ; rebroadcast : origin_topics:string list -> Mina_block.Validated.t -> unit
  }

let handle_broadcasts ~logger ~time_controller ~consensus_constants
    ~broadcast_actions transition source valid_cbs =
  let hash =
    Mina_block.Validated.forget transition
    |> State_hash.With_state_hashes.state_hash
  in
  let consensus_state =
    transition |> Mina_block.Validated.header |> Header.protocol_state
    |> Mina_state.Protocol_state.consensus_state
  in
  let now =
    let open Block_time in
    now time_controller |> to_span_since_epoch |> Span.to_ms
  in
  match
    Consensus.Hooks.received_at_valid_time ~constants:consensus_constants
      ~time_received:now consensus_state
  with
  | Ok () ->
      ( match source with
      | `Gossip origin_topics ->
          broadcast_actions.rebroadcast ~origin_topics transition
      | `Internal ->
          (*Send callback to publish the new block. Don't log rebroadcast message if it is internally generated; There is a broadcast log*)
          broadcast_actions.broadcast transition
      | `Catchup ->
          (*Noop for directly downloaded transitions*)
          () ) ;
      List.iter
        ~f:
          (Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired
             `Accept )
        valid_cbs
  | Error reason -> (
      let timing_error_json =
        match reason with
        | `Too_early ->
            `String "too early"
        | `Too_late slots ->
            `String (sprintf "%Lu slots too late" slots)
      in
      let metadata =
        [ ("state_hash", State_hash.to_yojson hash)
        ; ("block", Mina_block.Validated.to_yojson transition)
        ; ("timing", timing_error_json)
        ]
      in
      List.iter
        ~f:
          (Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired
             `Reject )
        valid_cbs ;
      match source with
      | `Catchup ->
          ()
      | `Internal ->
          [%log error] ~metadata
            "Internally generated block $state_hash cannot be rebroadcast \
             because it's not a valid time to do so ($timing)"
      | `Gossip topics ->
          [%log warn]
            ~metadata:
              ( ("topics", `List (List.map topics ~f:(fun t -> `String t)))
              :: metadata )
            "Not rebroadcasting block $state_hash because it was received \
             $timing" )

(* add a breadcrumb and perform post processing *)
let add_and_finalize ~broadcast_actions ~logger ~frontier ~catchup_scheduler
    ~processed_transition_writer ~only_if_present ~time_controller ~source
    ~valid_cbs cached_breadcrumb ~(precomputed_values : Precomputed_values.t) =
  let breadcrumb =
    if Cached.is_pure cached_breadcrumb then Cached.peek cached_breadcrumb
    else Cached.invalidate_with_success cached_breadcrumb
  in
  let consensus_constants = precomputed_values.consensus_constants in
  let transition =
    Transition_frontier.Breadcrumb.validated_transition breadcrumb
  in
  [%log debug] "add_and_finalize $state_hash %s callback"
    ~metadata:
      [ ( "state_hash"
        , Transition_frontier.Breadcrumb.state_hash breadcrumb
          |> State_hash.to_yojson )
      ]
    (if List.is_empty valid_cbs then "without" else "with") ;
  let state_hash = Transition_frontier.Breadcrumb.state_hash breadcrumb in
  Internal_tracing.with_state_hash state_hash
  @@ fun () ->
  [%log internal] "Add_and_finalize" ;
  let%map () =
    if only_if_present then (
      let parent_hash = Transition_frontier.Breadcrumb.parent_hash breadcrumb in
      match Transition_frontier.find frontier parent_hash with
      | Some _ ->
          Transition_frontier.add_breadcrumb_exn frontier breadcrumb
      | None ->
          [%log internal] "Parent_breadcrumb_not_found" ;
          [%log warn]
            !"When trying to add breadcrumb, its parent had been removed from \
              transition frontier: %{sexp: State_hash.t}"
            parent_hash ;
          Deferred.unit )
    else Transition_frontier.add_breadcrumb_exn frontier breadcrumb
  in
  ( match source with
  | `Internal ->
      ()
  | _ ->
      record_block_inclusion_time transition ~time_controller
        ~consensus_constants ) ;
  [%log internal] "Add_and_finalize_done" ;
  handle_broadcasts ~logger ~time_controller ~consensus_constants
    ~broadcast_actions transition source valid_cbs ;
  if Writer.is_closed processed_transition_writer then
    Or_error.error_string "processed transitions closed"
  else (
    Writer.write processed_transition_writer transition ;
    Catchup_scheduler.notify catchup_scheduler
      ~hash:(Mina_block.Validated.state_hash transition) )

let handle_frontier_validation_error ~trust_system ~logger ~senders ~state_hash
    =
  let metadata = [ ("state_hash", State_hash.to_yojson state_hash) ] in
  let f sender =
    Trust_system.record_envelope_sender trust_system logger sender
      ( Trust_system.Actions.Gossiped_invalid_transition
      , Some
          ( "The transition with hash $state_hash was not selected over the \
             transition frontier root"
          , metadata ) )
  in
  function
  | `Not_selected_over_frontier_root ->
      [%log internal] "Failure"
        ~metadata:[ ("reason", `String "Not_selected_over_frontier_root") ] ;
      don't_wait_for (Deferred.List.iter senders ~f)
  | `Already_in_frontier ->
      [%log internal] "Failure"
        ~metadata:[ ("reason", `String "Already_in_frontier") ] ;
      [%log warn] ~metadata
        "Refusing to process the transition with hash $state_hash because is \
         is already in the transition frontier"

let process_transition ~context:(module Context : CONTEXT) ~broadcast_actions
    ~trust_system ~verifier ~get_completed_work ~frontier ~catchup_scheduler
    ~processed_transition_writer ~time_controller ~gd_map block_or_header =
  let valid_cbs = Transition_frontier.Gossip.valid_cbs gd_map in
  let open Context in
  let header, state_hash, validation =
    match block_or_header with
    | `Block cached ->
        let block, v = Cached.peek cached in
        ( Mina_block.header @@ With_hash.data block
        , State_hash.With_state_hashes.state_hash block
        , v )
    | `Header (h, v) ->
        (With_hash.data h, State_hash.With_state_hashes.state_hash h, v)
  in
  let parent_hash =
    Protocol_state.previous_state_hash (Header.protocol_state header)
  in
  let root_block =
    Transition_frontier.(Breadcrumb.block_with_hash @@ root frontier)
  in
  let is_block_in_frontier =
    Fn.compose Option.is_some @@ Transition_frontier.find frontier
  in
  Internal_tracing.with_state_hash state_hash
  @@ fun () ->
  [%log internal] "@block_metadata"
    ~metadata:
      [ ( "blockchain_length"
        , Mina_numbers.Length.to_yojson (Header.blockchain_length header) )
      ] ;
  [%log internal] "Begin_external_block_processing" ;
  let senders =
    String.Map.data gd_map
    |> List.map ~f:(fun { Transition_frontier.Gossip.sender; _ } -> sender)
  in
  let transition_receipt_time =
    String.Map.data gd_map
    |> List.map ~f:(fun { Transition_frontier.Gossip.received_at; _ } ->
           received_at )
    |> List.min_elt ~compare:Time.compare
  in
  match block_or_header with
  | `Header hv -> (
      let header_with_hash = Mina_block.Validation.header_with_hash hv in
      [%log internal] "Validate_frontier_dependencies" ;
      return
      @@
      match
        Mina_block.Validation.validate_frontier_dependencies
          ~context:(module Context)
          ~root_block ~is_block_in_frontier ~to_header:ident hv
      with
      (* TODO need more internal logging? *)
      | Ok _ ->
          Catchup_scheduler.watch_header catchup_scheduler ~gd_map
            ~header_with_hash
      | Error `Parent_missing_from_frontier ->
          [%log internal] "Schedule_catchup" ;
          Catchup_scheduler.watch_header catchup_scheduler ~gd_map
            ~header_with_hash
      | _ ->
          () )
  | `Block cached_initially_validated_transition ->
      Deferred.map ~f:(Fn.const ())
      @@
      let open Deferred.Result.Let_syntax in
      let%bind mostly_validated_transition =
        let open Deferred.Let_syntax in
        let initially_validated_transition =
          Cached.peek cached_initially_validated_transition
        in
        [%log internal] "Validate_frontier_dependencies" ;
        match
          Mina_block.Validation.validate_frontier_dependencies
            ~context:(module Context)
            ~root_block ~is_block_in_frontier ~to_header:Mina_block.header
            initially_validated_transition
        with
        | Ok t ->
            return (Ok t)
        | Error `Parent_missing_from_frontier -> (
            [%log internal] "Schedule_catchup" ;
            match validation with
            | ( _
              , _
              , _
              , (`Delta_block_chain, Truth.True delta_state_hashes)
              , _
              , _
              , _ ) ->
                let timeout_duration =
                  Option.fold
                    (Transition_frontier.find frontier
                       (Mina_stdlib.Nonempty_list.head delta_state_hashes) )
                    ~init:(Block_time.Span.of_ms 0L)
                    ~f:(fun _ _ -> catchup_timeout_duration precomputed_values)
                in
                Catchup_scheduler.watch catchup_scheduler ~timeout_duration
                  ~cached_transition:cached_initially_validated_transition
                  ~gd_map ;
                return (Error ()) )
        | Error (`Not_selected_over_frontier_root as e)
        | Error (`Already_in_frontier as e) ->
            handle_frontier_validation_error ~trust_system ~logger ~senders
              ~state_hash e ;
            let (_ : Mina_block.initial_valid_block) =
              Cached.invalidate_with_failure
                cached_initially_validated_transition
            in
            return (Error ())
      in
      (* TODO: only access parent in transition frontier once (already done in call to validate dependencies) #2485 *)
      [%log internal] "Find_parent_breadcrumb" ;
      let parent_breadcrumb =
        Transition_frontier.find_exn frontier parent_hash
      in
      let%bind breadcrumb =
        cached_transform_deferred_result cached_initially_validated_transition
          ~transform_cached:(fun _ ->
            Transition_frontier.Breadcrumb.build ~logger ~precomputed_values
              ~verifier ~get_completed_work ~trust_system
              ~transition_receipt_time ~senders ~parent:parent_breadcrumb
              ~transition:mostly_validated_transition
              (* TODO: Can we skip here? *) () )
          ~transform_result:(function
            | Error (`Invalid_staged_ledger_hash error)
            | Error (`Invalid_staged_ledger_diff error) ->
                Internal_tracing.with_state_hash state_hash
                @@ fun () ->
                [%log internal] "Failure"
                  ~metadata:[ ("reason", `String (Error.to_string_hum error)) ] ;
                [%log error]
                  ~metadata:
                    [ ("error", Error_json.error_to_yojson error)
                    ; ("state_hash", State_hash.to_yojson state_hash)
                    ]
                  "Error while building breadcrumb in the transition handler \
                   processor: $error" ;
                Deferred.return (Error ())
            | Error (`Fatal_error exn) ->
                Internal_tracing.with_state_hash state_hash
                @@ fun () ->
                [%log internal] "Failure"
                  ~metadata:[ ("reason", `String "Fatal error") ] ;
                raise exn
            | Ok breadcrumb ->
                Deferred.return (Ok breadcrumb) )
      in
      let topics = String.Map.keys gd_map in
      (* Mina_metrics.(
         Counter.inc_one
           Transition_frontier_controller.breadcrumbs_built_by_processor) ; *)
      let%map.Deferred result =
        add_and_finalize ~broadcast_actions ~logger ~frontier ~catchup_scheduler
          ~processed_transition_writer ~only_if_present:false ~time_controller
          ~source:(`Gossip topics) breadcrumb ~precomputed_values ~valid_cbs
      in
      ( match result with
      | Ok () ->
          [%log internal] "Breadcrumb_integrated"
      | Error err ->
          [%log internal] "Failure"
            ~metadata:[ ("reason", `String (Error.to_string_hum err)) ] ) ;
      Result.return result

let run_impl ~broadcast_actions ~context:(module Context : CONTEXT) ~verifier
    ~trust_system ~time_controller ~frontier ~get_completed_work
    ~(primary_transition_reader :
       ( [ `Block of (Mina_block.initial_valid_block, State_hash.t) Cached.t
         | `Header of Mina_block.initial_valid_header ]
       * [ `Gossip_map of Transition_frontier.Gossip.gossip_map ] )
       Reader.t )
    ~(producer_transition_reader : Transition_frontier.Breadcrumb.t Reader.t)
    ~(clean_up_catchup_scheduler : unit Ivar.t) ~catchup_job_writer
    ~(catchup_breadcrumbs_reader :
       ( ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
         * Transition_frontier.Gossip.gossip_map )
         Rose_tree.t
         list
       * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ] )
       Reader.t )
    ~(catchup_breadcrumbs_writer :
       ( ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
         * Transition_frontier.Gossip.gossip_map )
         Rose_tree.t
         list
         * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ]
       , crash buffered
       , unit )
       Writer.t ) ~processed_transition_writer =
  let open Context in
  let catchup_scheduler =
    Catchup_scheduler.create ~logger ~precomputed_values ~verifier ~trust_system
      ~frontier ~time_controller ~catchup_job_writer ~catchup_breadcrumbs_writer
      ~clean_up_signal:clean_up_catchup_scheduler
  in
  let add_and_finalize =
    add_and_finalize ~broadcast_actions ~frontier ~catchup_scheduler
      ~processed_transition_writer ~time_controller ~precomputed_values
  in
  let process_transition =
    process_transition
      ~context:(module Context)
      ~get_completed_work ~broadcast_actions ~trust_system ~verifier ~frontier
      ~catchup_scheduler ~processed_transition_writer ~time_controller
  in
  O1trace.background_thread "process_blocks" (fun () ->
      Reader.Merge.iter
        (* It is fine to skip the cache layer on blocks produced by this node
           * because it is extraordinarily unlikely we would write an internal bug
           * triggering this case, and the external case (where we received an
           * identical external transition from the network) can happen iff there
           * is another node with the exact same private key and view of the
           * transaction pool. *)
        [ Reader.map producer_transition_reader ~f:(fun breadcrumb ->
              Mina_metrics.(
                Gauge.inc_one
                  Transition_frontier_controller.transitions_being_processed) ;
              `Local_breadcrumb (Cached.pure breadcrumb) )
        ; Reader.map catchup_breadcrumbs_reader ~f:(fun el ->
              `Catchup_breadcrumbs el )
        ; Reader.map primary_transition_reader ~f:(fun vt ->
              `Partially_valid_transition vt )
        ]
        ~f:(fun msg ->
          let open Deferred.Let_syntax in
          O1trace.thread "transition_handler_processor" (fun () ->
              match msg with
              | `Catchup_breadcrumbs
                  (breadcrumb_subtrees, subsequent_callback_action) -> (
                  ( match%map
                      Deferred.Or_error.List.iter breadcrumb_subtrees
                        ~f:(fun subtree ->
                          Rose_tree.Deferred.Or_error.iter
                            subtree
                            (* It could be the case that by the time we try and
                               * add the breadcrumb, it's no longer relevant when
                               * we're catching up *) ~f:(fun (b, gd_map) ->
                              let state_hash =
                                Frontier_base.Breadcrumb.state_hash
                                  (Cached.peek b)
                              in
                              let valid_cbs =
                                Transition_frontier.Gossip.valid_cbs gd_map
                              in
                              let%map result =
                                add_and_finalize ~logger ~only_if_present:true
                                  ~source:`Catchup ~valid_cbs b
                              in
                              Internal_tracing.with_state_hash state_hash
                              @@ fun () ->
                              ( match result with
                              | Error err ->
                                  [%log internal] "Failure"
                                    ~metadata:
                                      [ ( "reason"
                                        , `String (Error.to_string_hum err) )
                                      ]
                              | Ok () ->
                                  [%log internal] "Breadcrumb_integrated" ) ;
                              result ) )
                    with
                  | Ok () ->
                      ()
                  | Error err ->
                      List.iter breadcrumb_subtrees ~f:(fun tree ->
                          Rose_tree.iter tree
                            ~f:(fun (cached_breadcrumb, _vc) ->
                              let (_ : Transition_frontier.Breadcrumb.t) =
                                Cached.invalidate_with_failure cached_breadcrumb
                              in
                              () ) ) ;
                      [%log error]
                        "Error, failed to attach all catchup breadcrumbs to \
                         transition frontier: $error"
                        ~metadata:[ ("error", Error_json.error_to_yojson err) ]
                  )
                  >>| fun () ->
                  match subsequent_callback_action with
                  | `Ledger_catchup decrement_signal ->
                      if Ivar.is_full decrement_signal then
                        [%log error] "Ivar.fill bug is here!" ;
                      Ivar.fill decrement_signal ()
                  | `Catchup_scheduler ->
                      () )
              | `Local_breadcrumb breadcrumb ->
                  let state_hash =
                    Transition_frontier.Breadcrumb.validated_transition
                      (Cached.peek breadcrumb)
                    |> Mina_block.Validated.state_hash
                  in
                  Internal_tracing.with_state_hash state_hash
                  @@ fun () ->
                  [%log internal] "Begin_local_block_processing" ;
                  let transition_time =
                    Transition_frontier.Breadcrumb.validated_transition
                      (Cached.peek breadcrumb)
                    |> Mina_block.Validated.header
                    |> Mina_block.Header.protocol_state
                    |> Protocol_state.blockchain_state
                    |> Blockchain_state.timestamp |> Block_time.to_time_exn
                  in
                  Perf_histograms.add_span
                    ~name:"accepted_transition_local_latency"
                    (Core_kernel.Time.diff
                       Block_time.(now time_controller |> to_time_exn)
                       transition_time ) ;
                  let%map () =
                    match%map
                      add_and_finalize ~logger ~only_if_present:false
                        ~source:`Internal breadcrumb ~valid_cbs:[]
                    with
                    | Ok () ->
                        [%log internal] "Breadcrumb_integrated" ;
                        ()
                    | Error err ->
                        [%log internal] "Failure"
                          ~metadata:
                            [ ("reason", `String (Error.to_string_hum err)) ] ;
                        [%log error]
                          ~metadata:
                            [ ("error", Error_json.error_to_yojson err) ]
                          "Error, failed to attach produced breadcrumb to \
                           transition frontier: $error" ;
                        let (_ : Transition_frontier.Breadcrumb.t) =
                          Cached.invalidate_with_failure breadcrumb
                        in
                        ()
                  in
                  Mina_metrics.(
                    Gauge.dec_one
                      Transition_frontier_controller.transitions_being_processed)
              | `Partially_valid_transition (block_or_header, `Gossip_map gd_map)
                ->
                  process_transition ~gd_map block_or_header ) ) )

let run ~network =
  run_impl
    ~broadcast_actions:
      { broadcast =
          (fun b ->
            let b = Mina_block.Validated.forget b in
            don't_wait_for @@ Mina_networking.broadcast_transition network b )
      ; rebroadcast =
          (fun ~origin_topics b ->
            let b = Mina_block.Validated.forget b in
            don't_wait_for
            @@ Mina_networking.rebroadcast_transition network ~origin_topics
                 (`Block b) )
      }

let%test_module "Transition_handler.Processor tests" =
  ( module struct
    open Async
    open Pipe_lib

    let () =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      Async.Scheduler.set_record_backtraces true

    let logger = Logger.create ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let proof_level = precomputed_values.proof_level

    let constraint_constants = precomputed_values.constraint_constants

    let time_controller = Block_time.Controller.basic ~logger

    let trust_system = Trust_system.null ()

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            () )

    module Context = struct
      let logger = logger

      let precomputed_values = precomputed_values

      let constraint_constants = constraint_constants

      let consensus_constants = precomputed_values.consensus_constants
    end

    let downcast_breadcrumb breadcrumb =
      let transition =
        Transition_frontier.Breadcrumb.validated_transition breadcrumb
        |> Mina_block.Validated.remember
        |> Mina_block.Validation.reset_frontier_dependencies_validation
        |> Mina_block.Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:transition ~sender:Envelope.Sender.Local

    let%test_unit "adding transitions whose parents are in the frontier" =
      let frontier_size = 1 in
      let branch_size = 10 in
      let max_length = frontier_size + branch_size in
      Quickcheck.test ~trials:4
        (Transition_frontier.For_tests.gen_with_branch ~precomputed_values
           ~verifier ~max_length ~frontier_size ~branch_size () )
        ~f:(fun (frontier, branch) ->
          assert (
            Thread_safe.block_on_async_exn (fun () ->
                let valid_transition_reader, valid_transition_writer =
                  Strict_pipe.create
                    (Buffered
                       (`Capacity branch_size, `Overflow (Drop_head ignore)) )
                in
                let producer_transition_reader, _ =
                  Strict_pipe.create
                    (Buffered
                       (`Capacity branch_size, `Overflow (Drop_head ignore)) )
                in
                let _, catchup_job_writer =
                  Strict_pipe.create (Buffered (`Capacity 1, `Overflow Crash))
                in
                let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
                  Strict_pipe.create (Buffered (`Capacity 1, `Overflow Crash))
                in
                let processed_transition_reader, processed_transition_writer =
                  Strict_pipe.create
                    (Buffered
                       (`Capacity branch_size, `Overflow (Drop_head ignore)) )
                in
                let clean_up_catchup_scheduler = Ivar.create () in
                let cache = Unprocessed_transition_cache.create ~logger in
                run_impl
                  ~broadcast_actions:
                    { broadcast = Fn.ignore
                    ; rebroadcast = (fun ~origin_topics:_ _ -> ())
                    }
                  ~context:(module Context)
                  ~time_controller ~verifier ~get_completed_work:(Fn.const None)
                  ~trust_system ~clean_up_catchup_scheduler ~frontier
                  ~primary_transition_reader:valid_transition_reader
                  ~producer_transition_reader ~catchup_job_writer
                  ~catchup_breadcrumbs_reader ~catchup_breadcrumbs_writer
                  ~processed_transition_writer ;
                List.iter branch ~f:(fun breadcrumb ->
                    let b =
                      downcast_breadcrumb breadcrumb
                      |> Unprocessed_transition_cache.register_exn cache
                      |> Cached.transform ~f:Envelope.Incoming.data
                    in
                    Strict_pipe.Writer.write valid_transition_writer
                      (`Block b, `Gossip_map String.Map.empty) ) ;
                match%map
                  Block_time.Timeout.await
                    ~timeout_duration:(Block_time.Span.of_ms 30000L)
                    time_controller
                    (Strict_pipe.Reader.fold_until processed_transition_reader
                       ~init:branch
                       ~f:(fun remaining_breadcrumbs newly_added_transition ->
                         Deferred.return
                           ( match remaining_breadcrumbs with
                           | next_expected_breadcrumb :: tail ->
                               [%test_eq: State_hash.t]
                                 (Transition_frontier.Breadcrumb.state_hash
                                    next_expected_breadcrumb )
                                 (Mina_block.Validated.state_hash
                                    newly_added_transition ) ;
                               [%log info]
                                 ~metadata:
                                   [ ( "height"
                                     , `Int
                                         ( newly_added_transition
                                         |> Mina_block.Validated.forget
                                         |> With_hash.data |> Mina_block.header
                                         |> Mina_block.Header.protocol_state
                                         |> Protocol_state.consensus_state
                                         |> Consensus.Data.Consensus_state
                                            .blockchain_length
                                         |> Mina_numbers.Length.to_uint32
                                         |> Unsigned.UInt32.to_int ) )
                                   ]
                                 "transition of $height passed processor" ;
                               if List.is_empty tail then `Stop true
                               else `Continue tail
                           | [] ->
                               `Stop false ) ) )
                with
                | `Timeout ->
                    failwith "test timed out"
                | `Ok (`Eof _) ->
                    failwith "pipe closed unexpectedly"
                | `Ok (`Terminated x) ->
                    x ) ) )
  end )
