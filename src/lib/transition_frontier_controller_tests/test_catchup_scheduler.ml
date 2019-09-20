open Async
open Core
open Coda_base
open Cache_lib
open Pipe_lib
open Coda_transition

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

module Inputs = struct
  include Transition_frontier_inputs
  module Time = Time
  module State_proof = State_proof
  module Transition_frontier = Transition_frontier
end

module Catchup_scheduler =
  Transition_handler.Components.Catchup_scheduler.Make (Inputs)
module Transition_handler = Transition_handler.Make (Inputs)
open Transition_handler

let%test_module "Transition_handler.Catchup_scheduler tests" =
  ( module struct
    let logger = Logger.null ()

    let pids = Child_processes.Termination.create_pid_set ()

    let trust_system = Trust_system.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let timeout_duration = Block_time.Span.of_ms 200L

    let accounts_with_secret_keys = Genesis_ledger.accounts

    let num_breadcrumbs = 5

    let setup_random_frontier () =
      let open Deferred.Let_syntax in
      let%bind frontier =
        create_root_frontier ~logger ~pids accounts_with_secret_keys
      in
      let%map (_ : unit) =
        build_frontier_randomly
          ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
            Quickcheck.Generator.with_size ~size:num_breadcrumbs
            @@ Quickcheck_lib.gen_imperative_ktree
                 (root_breadcrumb |> return |> Quickcheck.Generator.return)
                 (gen_breadcrumb ~logger ~pids ~trust_system
                    ~accounts_with_secret_keys) )
          frontier
      in
      frontier

    let extract_children_from ~reader ~root =
      let open Deferred.Let_syntax in
      let result_ivar = Ivar.create () in
      Strict_pipe.Reader.iter_without_pushback reader ~f:(fun children ->
          Ivar.fill result_ivar children )
      |> don't_wait_for ;
      let%map children = Ivar.read result_ivar in
      Rose_tree.T (root, children)

    let create_catchup_scheduler () =
      let%map verifier = Verifier.create ~logger ~pids in
      Catchup_scheduler.create ~verifier

    let%test_unit "after the timeout expires, the missing node still doesn't \
                   show up, so the catchup job is fired" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier = setup_random_frontier () in
          let trust_system = Trust_system.null () in
          let%bind create = create_catchup_scheduler () in
          let scheduler =
            create ~logger ~trust_system ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
              ~clean_up_signal:(Ivar.create ())
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value
                 (gen_linear_breadcrumbs ~logger ~pids ~trust_system ~size:2
                    ~accounts_with_secret_keys randomly_chosen_breadcrumb)
          in
          let missing_hash =
            List.hd_exn upcoming_breadcrumbs
            |> Transition_frontier.Breadcrumb.state_hash
          in
          let dangling_breadcrumb = List.nth_exn upcoming_breadcrumbs 1 in
          let dangling_transition =
            let transition =
              Transition_frontier.Breadcrumb.validated_transition
                dangling_breadcrumb
              |> External_transition.Validation
                 .reset_frontier_dependencies_validation
              |> External_transition.Validation
                 .reset_staged_ledger_diff_validation
            in
            Envelope.Incoming.wrap ~data:transition
              ~sender:Envelope.Sender.Local
            |> Cached.pure
          in
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~cached_transition:dangling_transition ;
          let result_ivar = Ivar.create () in
          Strict_pipe.Reader.iter_without_pushback catchup_job_reader
            ~f:(Ivar.fill result_ivar)
          |> don't_wait_for ;
          let%map catchup_parent_hash =
            match%map Ivar.read result_ivar with hash, _ -> hash
          in
          assert (Catchup_scheduler.is_empty scheduler) ;
          assert (Coda_base.State_hash.equal missing_hash catchup_parent_hash) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "if a linear sequence of transitions in reverse order, \
                   catchup scheduler should not create duplicate jobs" =
      let logger = Logger.null () in
      let _catchup_job_reader, catchup_job_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Unprocessed_transition_cache.create ~logger
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier = setup_random_frontier () in
          let trust_system = Trust_system.null () in
          let%bind create = create_catchup_scheduler () in
          let scheduler =
            create ~logger ~trust_system ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
              ~clean_up_signal:(Ivar.create ())
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let size = 4 in
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value
                 (gen_linear_breadcrumbs ~logger ~pids ~trust_system ~size
                    ~accounts_with_secret_keys randomly_chosen_breadcrumb)
          in
          let upcoming_transitions =
            List.map ~f:Transition_frontier.Breadcrumb.validated_transition
              upcoming_breadcrumbs
          in
          let missing_breadcrumb = List.hd_exn upcoming_breadcrumbs in
          let missing_transition = List.hd_exn upcoming_transitions in
          let dangling_transitions = List.tl_exn upcoming_transitions in
          let cached_dangling_transitions =
            List.map dangling_transitions ~f:(fun transition ->
                let transition =
                  transition
                  |> External_transition.Validation
                     .reset_frontier_dependencies_validation
                  |> External_transition.Validation
                     .reset_staged_ledger_diff_validation
                in
                Envelope.Incoming.wrap ~data:transition
                  ~sender:Envelope.Sender.Local
                |> Unprocessed_transition_cache.register_exn
                     unprocessed_transition_cache )
          in
          List.(
            iter (rev cached_dangling_transitions) ~f:(fun cached_transition ->
                Catchup_scheduler.watch scheduler ~timeout_duration
                  ~cached_transition ;
                assert (
                  Catchup_scheduler.has_timeout scheduler
                    ( Cached.peek cached_transition
                    |> Envelope.Incoming.data |> fst |> With_hash.data ) ) )) ;
          let%bind (_ : unit) =
            Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb
          in
          Catchup_scheduler.notify scheduler
            ~hash:(External_transition.Validated.state_hash missing_transition)
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let%map cached_received_rose_tree =
            extract_children_from
              ~reader:
                (Strict_pipe.Reader.map catchup_breadcrumbs_reader
                   ~f:(fun (rose_trees, _) -> rose_trees))
              ~root:
                ( Unprocessed_transition_cache.register_exn
                    unprocessed_transition_cache
                    (let transition =
                       Transition_frontier.Breadcrumb.validated_transition
                         missing_breadcrumb
                       |> External_transition.Validation
                          .reset_frontier_dependencies_validation
                       |> External_transition.Validation
                          .reset_staged_ledger_diff_validation
                     in
                     Envelope.Incoming.wrap ~data:transition
                       ~sender:Envelope.Sender.Local)
                |> Cached.transform ~f:(Fn.const missing_breadcrumb) )
          in
          let received_rose_tree =
            Rose_tree.map cached_received_rose_tree
              ~f:Cached.invalidate_with_success
          in
          assert (
            List.equal Transition_frontier.Breadcrumb.equal
              (Rose_tree.flatten received_rose_tree)
              upcoming_breadcrumbs ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "If a non-linear sequence of transitions out of order and \
                   the missing node is received before the timeout expires, \
                   the timeout would be canceled" =
      let _catchup_job_reader, catchup_job_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Unprocessed_transition_cache.create ~logger
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier = setup_random_frontier () in
          let trust_system = Trust_system.null () in
          let%bind create = create_catchup_scheduler () in
          let scheduler =
            create ~logger ~trust_system ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
              ~clean_up_signal:(Ivar.create ())
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let%bind upcoming_rose_tree =
            Rose_tree.Deferred.all
            @@ Quickcheck.random_value
                 (gen_tree ~logger ~pids ~trust_system ~size:5
                    ~accounts_with_secret_keys randomly_chosen_breadcrumb)
          in
          let upcoming_breadcrumbs = Rose_tree.flatten upcoming_rose_tree in
          let upcoming_transitions =
            List.map ~f:Transition_frontier.Breadcrumb.validated_transition
              upcoming_breadcrumbs
          in
          let missing_breadcrumb = List.hd_exn upcoming_breadcrumbs in
          let missing_transition = List.hd_exn upcoming_transitions in
          let dangling_transitions = List.tl_exn upcoming_transitions in
          let cached_dangling_transitions =
            List.map dangling_transitions ~f:(fun transition ->
                let transition =
                  transition
                  |> External_transition.Validation
                     .reset_frontier_dependencies_validation
                  |> External_transition.Validation
                     .reset_staged_ledger_diff_validation
                in
                Envelope.Incoming.wrap ~data:transition
                  ~sender:Envelope.Sender.Local
                |> Unprocessed_transition_cache.register_exn
                     unprocessed_transition_cache )
          in
          List.iter (List.permute cached_dangling_transitions)
            ~f:(fun cached_transition ->
              Catchup_scheduler.watch scheduler ~timeout_duration
                ~cached_transition ) ;
          assert (not @@ Catchup_scheduler.is_empty scheduler) ;
          let%bind (_ : unit) =
            Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb
          in
          Catchup_scheduler.notify scheduler
            ~hash:(External_transition.Validated.state_hash missing_transition)
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let%map cached_received_rose_tree =
            extract_children_from
              ~reader:
                (Strict_pipe.Reader.map catchup_breadcrumbs_reader
                   ~f:(fun (rose_trees, _) -> rose_trees))
              ~root:
                ( Unprocessed_transition_cache.register_exn
                    unprocessed_transition_cache
                    (let transition =
                       Transition_frontier.Breadcrumb.validated_transition
                         missing_breadcrumb
                       |> External_transition.Validation
                          .reset_frontier_dependencies_validation
                       |> External_transition.Validation
                          .reset_staged_ledger_diff_validation
                     in
                     Envelope.Incoming.wrap ~data:transition
                       ~sender:Envelope.Sender.Local)
                |> Cached.transform ~f:(Fn.const missing_breadcrumb) )
          in
          let received_rose_tree =
            Rose_tree.map cached_received_rose_tree
              ~f:Cached.invalidate_with_success
          in
          assert (
            Rose_tree.equiv received_rose_tree upcoming_rose_tree
              ~f:Transition_frontier.Breadcrumb.equal ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )
  end )
