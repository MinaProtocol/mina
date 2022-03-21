(** [Catchup_scheduler] defines a process which schedules catchup jobs and
    monitors them for invalidation. This allows the transition frontier
    controller to handle out of order blocks without spinning up and
    tearing down catchup jobs constantly. The [Catchup_scheduler] must receive
    notifications whenever a new block is added to the transition frontier
    so that it can determine if any pending catchup jobs can be invalidated.
    When catchup jobs are invalidated, the catchup scheduler extracts all of
    the invalidated catchup jobs and spins up a process to materialize
    breadcrumbs from those blocks, which will write the breadcrumbs back
    into the processor as if catchup had successfully completed. *)

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe
open Cache_lib
open Otp_lib
open Mina_base
open Mina_state
open Network_peer

type t =
  { logger : Logger.t
  ; time_controller : Block_time.Controller.t
  ; catchup_job_writer :
      ( State_hash.t
        * ( Mina_block.initial_valid_block Envelope.Incoming.t
          , State_hash.t )
          Cached.t
          Rose_tree.t
          list
      , crash buffered
      , unit )
      Writer.t
        (** `collected_transitins` stores all seen blocks as its keys,
            and values are a list of direct children of those blocks.
            The invariant is that every collected block would appear as
            a key in this table. Even if a block doesn't has a child,
            its corresponding value in the hash table would just be an empty
            list. *)
  ; collected_blocks :
      ( Mina_block.initial_valid_block Envelope.Incoming.t
      , State_hash.t )
      Cached.t
      list
      State_hash.Table.t
        (** `parent_root_timeouts` stores the timeouts for catchup job. The
            keys are the missing blocks, and the values are the
            timeouts. *)
  ; parent_root_timeouts : unit Block_time.Timeout.t State_hash.Table.t
  ; breadcrumb_builder_supervisor :
      ( State_hash.t
      * ( Mina_block.initial_valid_block Envelope.Incoming.t
        , State_hash.t )
        Cached.t
        Rose_tree.t
        list )
      Capped_supervisor.t
  }

let create ~logger ~precomputed_values ~verifier ~trust_system ~frontier
    ~time_controller
    ~(catchup_job_writer :
       ( State_hash.t
         * ( Mina_block.initial_valid_block Envelope.Incoming.t
           , State_hash.t )
           Cached.t
           Rose_tree.t
           list
       , crash buffered
       , unit )
       Writer.t)
    ~(catchup_breadcrumbs_writer :
       ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
         list
         * [ `Ledger_catchup of unit Ivar.t | `Catchup_scheduler ]
       , crash buffered
       , unit )
       Writer.t) ~clean_up_signal =
  let collected_blocks = State_hash.Table.create () in
  let parent_root_timeouts = State_hash.Table.create () in
  upon (Ivar.read clean_up_signal) (fun () ->
      Hashtbl.iter collected_blocks ~f:(fun cached_blocks ->
          List.iter cached_blocks
            ~f:(Fn.compose ignore Cached.invalidate_with_failure)) ;
      Hashtbl.iter parent_root_timeouts ~f:(fun timeout ->
          Block_time.Timeout.cancel time_controller timeout ())) ;
  let breadcrumb_builder_supervisor =
    O1trace.trace_recurring "breadcrumb builder" (fun () ->
        Capped_supervisor.create ~job_capacity:30
          (fun (initial_hash, block_branches) ->
            match%map
              Breadcrumb_builder.build_subtrees_of_breadcrumbs
                ~logger:
                  (Logger.extend logger
                     [ ( "catchup_scheduler"
                       , `String "Called from catchup scheduler" )
                     ])
                ~precomputed_values ~verifier ~trust_system ~frontier
                ~initial_hash block_branches
            with
            | Ok trees_of_breadcrumbs ->
                Writer.write catchup_breadcrumbs_writer
                  (trees_of_breadcrumbs, `Catchup_scheduler)
            | Error err ->
                [%log debug]
                  !"Error during buildup breadcrumbs inside catchup_scheduler: \
                    $error"
                  ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
                List.iter block_branches ~f:(fun subtree ->
                    Rose_tree.iter subtree ~f:(fun cached_block ->
                        ignore
                          ( Cached.invalidate_with_failure cached_block
                            : Mina_block.initial_valid_block
                              Envelope.Incoming.t )))))
  in
  { logger
  ; collected_blocks
  ; time_controller
  ; catchup_job_writer
  ; parent_root_timeouts
  ; breadcrumb_builder_supervisor
  }

let mem t block =
  block
  |> Mina_block.header
  |> Mina_block.Header.protocol_state
  |> Protocol_state.previous_state_hash
  |> Hashtbl.mem t.collected_blocks

let mem_parent_hash t parent_hash =
  Hashtbl.mem t.collected_blocks parent_hash

let has_timeout t block =
  block
  |> Mina_block.header
  |> Mina_block.Header.protocol_state
  |> Protocol_state.previous_state_hash
  |> Hashtbl.mem t.parent_root_timeouts

let has_timeout_parent_hash t parent_hash =
  Hashtbl.mem t.parent_root_timeouts parent_hash

let is_empty t =
  Hashtbl.is_empty t.collected_blocks
  && Hashtbl.is_empty t.parent_root_timeouts

let cancel_timeout t hash =
  let remaining_time =
    Option.map
      (Hashtbl.find t.parent_root_timeouts hash)
      ~f:Block_time.Timeout.remaining_time
  in
  let cancel timeout = Block_time.Timeout.cancel t.time_controller timeout () in
  Hashtbl.change t.parent_root_timeouts hash
    ~f:Fn.(compose (const None) (Option.iter ~f:cancel)) ;
  remaining_time

let rec extract_subtree t cached_block =
  let { With_hash.hash; _ }, _ =
    Envelope.Incoming.data (Cached.peek cached_block)
  in
  let successors =
    Option.value ~default:[] (Hashtbl.find t.collected_blocks hash)
  in
  Rose_tree.T (cached_block, List.map successors ~f:(extract_subtree t))

let extract_forest t hash =
  let successors =
    Option.value ~default:[] (Hashtbl.find t.collected_blocks hash)
  in
  (hash, List.map successors ~f:(extract_subtree t))

let rec remove_tree t parent_hash =
  let children =
    Option.value ~default:[] (Hashtbl.find t.collected_blocks parent_hash)
  in
  Hashtbl.remove t.collected_blocks parent_hash ;
  Mina_metrics.(
    Gauge.dec_one
      Transition_frontier_controller.blocks_in_catchup_scheduler) ;
  List.iter children ~f:(fun child ->
      let { With_hash.hash; _ } =
        Envelope.Incoming.data (Cached.peek child)
        |> Mina_block.Validation.block_with_hash
      in
      remove_tree t hash)

let watch t ~timeout_duration ~cached_block =
  let {With_hash.data= block; hash} =
    Envelope.Incoming.data (Cached.peek cached_block)
    |> Mina_block.Validation.block_with_hash
  in
  let parent_hash =
    block
    |> Mina_block.header
    |> Mina_block.Header.protocol_state
    |> Protocol_state.previous_state_hash
  in
  let make_timeout duration =
    Block_time.Timeout.create t.time_controller duration ~f:(fun _ ->
        let forest = extract_forest t parent_hash in
        Hashtbl.remove t.parent_root_timeouts parent_hash ;
        Mina_metrics.(
          Gauge.dec_one
            Transition_frontier_controller.blocks_in_catchup_scheduler) ;
        remove_tree t parent_hash ;
        [%log' info t.logger]
          ~metadata:
            [ ("parent_hash", Mina_base.State_hash.to_yojson parent_hash)
            ; ( "duration"
              , `Int (Block_time.Span.to_ms duration |> Int64.to_int_trunc) )
            ; ( "cached_block"
              , Mina_block.to_yojson block)
            ]
          "Timed out waiting for the parent of $cached_block after \
           $duration ms, signalling a catchup job" ;
        (* it's ok to create a new thread here because the thread essentially does no work *)
        if Writer.is_closed t.catchup_job_writer then
          [%log' trace t.logger]
            "catchup job pipe was closed; attempt to write to closed pipe"
        else Writer.write t.catchup_job_writer forest)
  in
  match Hashtbl.find t.collected_blocks parent_hash with
  | None ->
      let remaining_time = cancel_timeout t hash in
      Hashtbl.add_exn t.collected_blocks ~key:parent_hash
        ~data:[ cached_block ] ;
      Hashtbl.update t.collected_blocks hash ~f:(Option.value ~default:[]) ;
      ignore
        ( Hashtbl.add t.parent_root_timeouts ~key:parent_hash
            ~data:
              (make_timeout
                 (Option.fold remaining_time ~init:timeout_duration
                    ~f:(fun _ remaining_time ->
                      Block_time.Span.min remaining_time timeout_duration)))
          : [ `Duplicate | `Ok ] ) ;
      Mina_metrics.(
        Gauge.inc_one
          Transition_frontier_controller.blocks_in_catchup_scheduler)
  | Some cached_sibling_blocks ->
      if
        List.exists cached_sibling_blocks
          ~f:(fun cached_sibling_block ->
            let { With_hash.hash = sibling_hash; _ }, _ =
              Envelope.Incoming.data (Cached.peek cached_sibling_block)
            in
            State_hash.equal hash sibling_hash)
      then
        [%log' debug t.logger]
          ~metadata:[ ("state_hash", State_hash.to_yojson hash) ]
          "Received request to watch block for catchup that already is \
           being watched: $state_hash"
      else
        let (_ : Block_time.Span.t option) = cancel_timeout t hash in
        Hashtbl.set t.collected_blocks ~key:parent_hash
          ~data:(cached_block :: cached_sibling_blocks) ;
        Hashtbl.update t.collected_blocks hash
          ~f:(Option.value ~default:[]) ;
        Mina_metrics.(
          Gauge.inc_one
            Transition_frontier_controller.blocks_in_catchup_scheduler)

let notify t ~hash =
  if
    (Option.is_none @@ Hashtbl.find t.parent_root_timeouts hash)
    && (Option.is_some @@ Hashtbl.find t.collected_blocks hash)
  then
    Or_error.errorf
      !"Received notification to kill catchup job on a \
        non-parent_root_block: %{sexp: State_hash.t}"
      hash
  else
    let (_ : Block_time.Span.t option) = cancel_timeout t hash in
    Option.iter (Hashtbl.find t.collected_blocks hash)
      ~f:(fun collected_blocks ->
        let block_subtrees =
          List.map collected_blocks ~f:(extract_subtree t)
        in
        Capped_supervisor.dispatch t.breadcrumb_builder_supervisor
          (hash, block_subtrees)) ;
    remove_tree t hash ;
    Or_error.return ()

let%test_module "Transition_handler.Catchup_scheduler tests" =
  ( module struct
    open Pipe_lib

    let () =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let proof_level = precomputed_values.proof_level

    let constraint_constants = precomputed_values.constraint_constants

    let trust_system = Trust_system.null ()

    let pids = Child_processes.Termination.create_pid_table ()

    let time_controller = Block_time.Controller.basic ~logger

    let max_length = 10

    let create = create ~logger ~trust_system ~time_controller

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None ~pids)

    (* cast a breadcrumb into a cached, enveloped, partially validated block *)
    let downcast_breadcrumb breadcrumb =
      let block =
        Transition_frontier.Breadcrumb.validated_block breadcrumb
        |> Mina_block.Validated.remember
        |> Mina_block.Validation.reset_frontier_dependencies_validation
        |> Mina_block.Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:block ~sender:Envelope.Sender.Local

    let%test_unit "catchup jobs fire after the timeout" =
      let timeout_duration = Block_time.Span.of_ms 200L in
      let test_delta = Block_time.Span.of_ms 100L in
      Quickcheck.test ~trials:3
        (Transition_frontier.For_tests.gen_with_branch ~precomputed_values
           ~verifier ~max_length ~frontier_size:1 ~branch_size:2 ())
        ~f:(fun (frontier, branch) ->
          let catchup_job_reader, catchup_job_writer =
            Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
            Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let disjoint_breadcrumb = List.last_exn branch in
          let scheduler =
            create ~frontier ~precomputed_values ~verifier ~catchup_job_writer
              ~catchup_breadcrumbs_writer ~clean_up_signal:(Ivar.create ())
          in
          watch scheduler ~timeout_duration
            ~cached_block:
              (Cached.pure @@ downcast_breadcrumb disjoint_breadcrumb) ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              match%map
                Block_time.Timeout.await
                  ~timeout_duration:
                    Block_time.Span.(timeout_duration + test_delta)
                  time_controller
                  (Strict_pipe.Reader.read catchup_job_reader)
              with
              | `Timeout ->
                  failwith "test timed out"
              | `Ok `Eof ->
                  failwith "pipe closed unexpectedly"
              | `Ok (`Ok (job_state_hash, _)) ->
                  [%test_eq: State_hash.t]
                    (Transition_frontier.Breadcrumb.parent_hash
                       disjoint_breadcrumb)
                    job_state_hash
                    ~message:
                      "the job emitted from the catchup scheduler should be \
                       for the disjoint breadcrumb" ;
                  if not (is_empty scheduler) then
                    failwith
                      "catchup scheduler should be empty after job is emitted" ;
                  Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
                  Strict_pipe.Writer.close catchup_job_writer))

    let%test_unit "catchup jobs do not fire after timeout if they are \
                   invalidated" =
      let timeout_duration = Block_time.Span.of_ms 200L in
      let test_delta = Block_time.Span.of_ms 400L in
      Quickcheck.test ~trials:3
        (Transition_frontier.For_tests.gen_with_branch ~precomputed_values
           ~verifier ~max_length ~frontier_size:1 ~branch_size:2 ())
        ~f:(fun (frontier, branch) ->
          let cache = Unprocessed_block_cache.create ~logger in
          let register_breadcrumb breadcrumb =
            Unprocessed_block_cache.register_exn cache
              (downcast_breadcrumb breadcrumb)
            |> Cached.transform ~f:(Fn.const breadcrumb)
          in
          let catchup_job_reader, catchup_job_writer =
            Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
            Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let[@warning "-8"] [ breadcrumb_1; breadcrumb_2 ] =
            List.map ~f:register_breadcrumb branch
          in
          let scheduler =
            create ~precomputed_values ~frontier ~verifier ~catchup_job_writer
              ~catchup_breadcrumbs_writer ~clean_up_signal:(Ivar.create ())
          in
          watch scheduler ~timeout_duration
            ~cached_block:
              (Cached.transform ~f:downcast_breadcrumb breadcrumb_2) ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              Transition_frontier.add_breadcrumb_exn frontier
                (Cached.peek breadcrumb_1)) ;
          Or_error.ok_exn
            (notify scheduler
               ~hash:
                 (Transition_frontier.Breadcrumb.state_hash
                    (Cached.peek breadcrumb_1))) ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              match%map
                Block_time.Timeout.await
                  ~timeout_duration:
                    Block_time.Span.(timeout_duration + test_delta)
                  time_controller
                  (Strict_pipe.Reader.read catchup_job_reader)
              with
              | `Timeout ->
                  ()
              | `Ok `Eof ->
                  failwith "pipe closed unexpectedly"
              | `Ok (`Ok _) ->
                  failwith
                    "job was emitted from the catchup scheduler even though \
                     the job was invalidated") ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              match%map
                Block_time.Timeout.await ~timeout_duration:test_delta
                  time_controller
                  (Strict_pipe.Reader.read catchup_breadcrumbs_reader)
              with
              | `Timeout ->
                  failwith "timed out waiting for catchup breadcrumbs"
              | `Ok `Eof ->
                  failwith "pipe closed unexpectedly"
              | `Ok
                  (`Ok
                    ( [ Rose_tree.T (received_breadcrumb, []) ]
                    , `Catchup_scheduler )) ->
                  [%test_eq: State_hash.t]
                    (Transition_frontier.Breadcrumb.state_hash
                       (Cached.peek received_breadcrumb))
                    (Transition_frontier.Breadcrumb.state_hash
                       (Cached.peek breadcrumb_2))
              | `Ok (`Ok _) ->
                  failwith "invalid breadcrumb builder response") ;
          ignore
            ( Cached.invalidate_with_success breadcrumb_1
              : Transition_frontier.Breadcrumb.t ) ;
          ignore
            ( Cached.invalidate_with_success breadcrumb_2
              : Transition_frontier.Breadcrumb.t ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer)

    let%test_unit "catchup scheduler should not create duplicate jobs when a \
                   sequence of blocks is added in reverse order" =
      let timeout_duration = Block_time.Span.of_ms 400L in
      Quickcheck.test ~trials:3
        (Transition_frontier.For_tests.gen_with_branch ~precomputed_values
           ~verifier ~max_length ~frontier_size:1 ~branch_size:5 ())
        ~f:(fun (frontier, branch) ->
          let catchup_job_reader, catchup_job_writer =
            Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
            Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              (Buffered (`Capacity 10, `Overflow Crash))
          in
          let scheduler =
            create ~precomputed_values ~frontier ~verifier ~catchup_job_writer
              ~catchup_breadcrumbs_writer ~clean_up_signal:(Ivar.create ())
          in
          let[@warning "-8"] (oldest_breadcrumb :: dependent_breadcrumbs) =
            List.rev branch
          in
          watch scheduler ~timeout_duration
            ~cached_block:
              (Cached.pure @@ downcast_breadcrumb oldest_breadcrumb) ;
          assert (
            has_timeout_parent_hash scheduler
              (Transition_frontier.Breadcrumb.parent_hash oldest_breadcrumb) ) ;
          ignore
            ( List.fold dependent_breadcrumbs ~init:oldest_breadcrumb
                ~f:(fun prev_breadcrumb curr_breadcrumb ->
                  watch scheduler ~timeout_duration
                    ~cached_block:
                      (Cached.pure @@ downcast_breadcrumb curr_breadcrumb) ;
                  assert (
                    not
                    @@ has_timeout_parent_hash scheduler
                         (Transition_frontier.Breadcrumb.parent_hash
                            prev_breadcrumb) ) ;
                  assert (
                    has_timeout_parent_hash scheduler
                      (Transition_frontier.Breadcrumb.parent_hash
                         curr_breadcrumb) ) ;
                  curr_breadcrumb)
              : Frontier_base.Breadcrumb.t ) ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              match%map Strict_pipe.Reader.read catchup_job_reader with
              | `Eof ->
                  failwith "pipe closed unexpectedly"
              | `Ok (job_hash, _) ->
                  [%test_eq: State_hash.t] job_hash
                    ( Transition_frontier.Breadcrumb.parent_hash
                    @@ List.hd_exn branch )))
  end )
