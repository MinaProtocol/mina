open Core
open Pipe_lib
open Async
open Coda_base
open Coda_transition

let max_length = 4

module Stubs = Stubs.Make (struct
  let max_length = max_length
end)

open Stubs

module Transition_handler = Transition_handler.Make (struct
  include Transition_frontier_inputs
  module Transition_frontier = Transition_frontier
  module State_proof = State_proof
  module Time = Time
end)

module Ledger_catchup = Ledger_catchup.Make (struct
  include Transition_frontier_inputs
  module Time = Time
  module Transition_frontier = Transition_frontier
  module Network = Network
  module Unprocessed_transition_cache =
    Transition_handler.Unprocessed_transition_cache
  module Transition_handler_validator = Transition_handler.Validator
  module Breadcrumb_builder = Transition_handler.Breadcrumb_builder
end)

let%test_module "Ledger catchup" =
  ( module struct
    let run_ledger_catchup ~logger ~pids =
      let%map verifier = Verifier.create ~logger ~pids in
      Ledger_catchup.run ~verifier

    let assert_catchup_jobs_are_flushed transition_frontier =
      [%test_result: [`Normal | `Catchup]]
        ~message:
          "Transition_frontier should not have any more catchup jobs at the \
           end of the test"
        ~equal:( = ) ~expect:`Normal
        ( Broadcast_pipe.Reader.peek
        @@ Transition_frontier.catchup_signal transition_frontier )

    let test_catchup ~logger ~pids ~trust_system ~network
        (me : Transition_frontier.t) transition expected_breadcrumbs =
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      let cached_transition =
        Transition_handler.Unprocessed_transition_cache.register_exn
          unprocessed_transition_cache transition
      in
      let parent_hash =
        Envelope.Incoming.data transition
        |> fst |> With_hash.data |> External_transition.parent_hash
      in
      Strict_pipe.Writer.write catchup_job_writer
        (parent_hash, [Rose_tree.T (cached_transition, [])]) ;
      let%bind run = run_ledger_catchup ~logger ~pids in
      run ~logger ~trust_system ~network ~frontier:me
        ~catchup_breadcrumbs_writer ~catchup_job_reader
        ~unprocessed_transition_cache ;
      let result_ivar = Ivar.create () in
      (* TODO: expose Strict_pipe.read *)
      Strict_pipe.Reader.iter catchup_breadcrumbs_reader ~f:(fun rose_tree ->
          Deferred.return @@ Ivar.fill result_ivar rose_tree )
      |> don't_wait_for ;
      let%bind cached_catchup_breadcrumbs =
        let%map breadcrumbs, catchup_signal = Ivar.read result_ivar in
        ( match catchup_signal with
        | `Catchup_scheduler ->
            failwith "Did not expect a catchup scheduler action"
        | `Ledger_catchup ivar ->
            Ivar.fill ivar () ) ;
        List.hd_exn breadcrumbs
      in
      let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
      let catchup_breadcrumbs =
        Rose_tree.map cached_catchup_breadcrumbs
          ~f:Cache_lib.Cached.invalidate_with_success
      in
      assert_catchup_jobs_are_flushed me ;
      Rose_tree.equal expected_breadcrumbs catchup_breadcrumbs
        ~f:(fun breadcrumb_tree1 breadcrumb_tree2 ->
          External_transition.Validated.equal
            (Transition_frontier.Breadcrumb.validated_transition
               breadcrumb_tree1)
            (Transition_frontier.Breadcrumb.validated_transition
               breadcrumb_tree2) )

    let%test "catchup to a peer" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer
              ~source_accounts:Genesis_ledger.accounts ~logger ~pids
              ~trust_system ~target_accounts:Genesis_ledger.accounts
              ~num_breadcrumbs:(max_length / 2)
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            let transition =
              Transition_frontier.Breadcrumb.validated_transition
                best_breadcrumb
              |> External_transition.Validation
                 .reset_frontier_dependencies_validation
              |> External_transition.Validation
                 .reset_staged_ledger_diff_validation
            in
            Envelope.Incoming.wrap ~data:transition
              ~sender:Envelope.Sender.Local
          in
          test_catchup ~logger ~pids ~trust_system ~network me best_transition
            ( Transition_frontier.path_map peer.frontier best_breadcrumb
                ~f:Fn.id
            |> Rose_tree.of_list_exn ) )

    let%test "peers can provide transitions with length between max_length to \
              2 * max_length" =
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      Thread_safe.block_on_async_exn (fun () ->
          let num_breadcrumbs =
            Int.gen_incl max_length (2 * max_length) |> Quickcheck.random_value
          in
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts ~num_breadcrumbs
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let best_transition_enveloped =
            let transition =
              best_transition
              |> External_transition.Validation
                 .reset_frontier_dependencies_validation
              |> External_transition.Validation
                 .reset_staged_ledger_diff_validation
            in
            Envelope.Incoming.wrap ~data:transition
              ~sender:Envelope.Sender.Local
          in
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ( "state_hash"
                , State_hash.to_yojson
                    (External_transition.Validated.state_hash best_transition)
                ) ]
            "Best transition of peer: $state_hash" ;
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (External_transition.Validated.state_hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          test_catchup ~logger ~pids ~trust_system ~network me
            best_transition_enveloped
            (Rose_tree.of_list_exn @@ Non_empty_list.tail history) )

    let%test "catchup would be successful even if the parent transition is \
              already in the frontier" =
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts ~num_breadcrumbs:1
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          test_catchup ~logger ~pids ~trust_system ~network me
            (let transition =
               best_transition
               |> External_transition.Validation
                  .reset_frontier_dependencies_validation
               |> External_transition.Validation
                  .reset_staged_ledger_diff_validation
             in
             Envelope.Incoming.wrap ~data:transition
               ~sender:Envelope.Sender.Local)
            (Rose_tree.of_list_exn [best_breadcrumb]) )

    let%test "catchup would fail if one of the parent transition fails" =
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts
              ~num_breadcrumbs:max_length
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (External_transition.Validated.state_hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          let missing_breadcrumbs = Non_empty_list.tail history in
          let missing_transitions =
            List.map missing_breadcrumbs
              ~f:Transition_frontier.Breadcrumb.validated_transition
          in
          let cached_best_transition =
            Transition_handler.Unprocessed_transition_cache.register_exn
              unprocessed_transition_cache
              (let transition =
                 best_transition
                 |> External_transition.Validation
                    .reset_frontier_dependencies_validation
                 |> External_transition.Validation
                    .reset_staged_ledger_diff_validation
               in
               Envelope.Incoming.wrap ~data:transition
                 ~sender:Envelope.Sender.Local)
          in
          let parent_hash =
            External_transition.Validated.parent_hash best_transition
          in
          Strict_pipe.Writer.write catchup_job_writer
            (parent_hash, [Rose_tree.T (cached_best_transition, [])]) ;
          let failing_transition = List.nth_exn missing_transitions 1 in
          let cached_failing_transition =
            Transition_handler.Unprocessed_transition_cache.register_exn
              unprocessed_transition_cache
              (let transition =
                 failing_transition
                 |> External_transition.Validation
                    .reset_frontier_dependencies_validation
                 |> External_transition.Validation
                    .reset_staged_ledger_diff_validation
               in
               Envelope.Incoming.wrap ~data:transition
                 ~sender:Envelope.Sender.Local)
          in
          let%bind run = run_ledger_catchup ~logger ~pids in
          run ~logger ~trust_system ~network ~frontier:me
            ~catchup_breadcrumbs_writer ~catchup_job_reader
            ~unprocessed_transition_cache ;
          let%bind () = after (Core.Time.Span.of_sec 1.) in
          Cache_lib.Cached.invalidate_with_failure cached_failing_transition
          |> ignore ;
          let%map result =
            Ivar.read (Cache_lib.Cached.final_state cached_best_transition)
          in
          result = `Failed )

    let%test_unit "catchup won't be blocked by transitions that are still \
                   under processing" =
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer
              ~source_accounts:Genesis_ledger.accounts ~logger ~pids
              ~trust_system ~target_accounts:Genesis_ledger.accounts
              ~num_breadcrumbs:max_length
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (External_transition.Validated.state_hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          let missing_breadcrumbs = Non_empty_list.tail history in
          let missing_transitions =
            List.map missing_breadcrumbs
              ~f:Transition_frontier.Breadcrumb.validated_transition
            |> List.rev
          in
          let last_breadcrumb = List.last_exn missing_breadcrumbs in
          let parent_hashes =
            List.map missing_transitions
              ~f:External_transition.Validated.parent_hash
          in
          let cached_transitions =
            List.map missing_transitions ~f:(fun transition ->
                let transition =
                  transition
                  |> External_transition.Validation
                     .reset_frontier_dependencies_validation
                  |> External_transition.Validation
                     .reset_staged_ledger_diff_validation
                in
                Envelope.Incoming.wrap ~data:transition
                  ~sender:Envelope.Sender.Local
                |> Transition_handler.Unprocessed_transition_cache.register_exn
                     unprocessed_transition_cache )
          in
          let forests =
            List.map2_exn parent_hashes cached_transitions
              ~f:(fun parent_hash cached_transition ->
                (parent_hash, [Rose_tree.T (cached_transition, [])]) )
          in
          List.iter forests ~f:(fun forest ->
              Deferred.upon
                (after (Core.Time.Span.of_ms 500.))
                (fun () -> Strict_pipe.Writer.write catchup_job_writer forest)
          ) ;
          let%bind run = run_ledger_catchup ~logger ~pids in
          run ~logger ~trust_system ~network ~frontier:me
            ~catchup_breadcrumbs_writer ~catchup_job_reader
            ~unprocessed_transition_cache ;
          let missing_breadcrumbs_queue =
            List.map missing_breadcrumbs ~f:(fun breadcrumb ->
                Rose_tree.T (breadcrumb, []) )
            |> Queue.of_list
          in
          let finished = Ivar.create () in
          Strict_pipe.Reader.iter catchup_breadcrumbs_reader
            ~f:(fun (rose_trees, catchup_signal) ->
              let catchup_breadcrumb_tree =
                Rose_tree.map (List.hd_exn rose_trees)
                  ~f:Cache_lib.Cached.invalidate_with_success
              in
              assert (
                List.length (Rose_tree.flatten catchup_breadcrumb_tree) = 1 ) ;
              let catchup_breadcrumb =
                List.hd_exn (Rose_tree.flatten catchup_breadcrumb_tree)
              in
              let expected_breadcrumb =
                List.hd_exn @@ Rose_tree.flatten
                @@ Queue.dequeue_exn missing_breadcrumbs_queue
              in
              assert (
                Transition_frontier.Breadcrumb.equal expected_breadcrumb
                  catchup_breadcrumb ) ;
              Transition_frontier.add_breadcrumb_exn me expected_breadcrumb
              |> ignore ;
              ( match catchup_signal with
              | `Catchup_scheduler ->
                  failwith "Did not expect a catchup scheduler action"
              | `Ledger_catchup ivar ->
                  Ivar.fill ivar () ) ;
              if
                Transition_frontier.Breadcrumb.equal expected_breadcrumb
                  last_breadcrumb
              then Ivar.fill finished () ;
              Deferred.unit )
          |> don't_wait_for ;
          let%bind () = Ivar.read finished in
          let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
          assert_catchup_jobs_are_flushed me )
  end )
