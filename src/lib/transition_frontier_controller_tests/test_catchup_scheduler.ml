open Async
open Core
open Pipe_lib

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

module Catchup_scheduler = Transition_handler.Catchup_scheduler.Make (struct
  module Time = Time
  include Transition_frontier_inputs
  module State_proof = State_proof
  module Transition_frontier = Transition_frontier
end)

let%test_module "Transition_handler.Catchup_scheduler tests" =
  ( module struct
    let logger = Logger.null ()

    let time_controller = Time.Controller.create ()

    let timeout_duration = Time.Span.of_ms 200L

    let accounts_with_secret_keys = Genesis_ledger.accounts

    let num_breadcrumbs = 5

    let setup_random_frontier () =
      let open Deferred.Let_syntax in
      let%bind frontier =
        create_root_frontier ~logger accounts_with_secret_keys
      in
      let%map _ : unit =
        build_frontier_randomly
          ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
            Quickcheck.Generator.with_size ~size:num_breadcrumbs
            @@ Quickcheck_lib.gen_imperative_ktree
                 (root_breadcrumb |> return |> Quickcheck.Generator.return)
                 (gen_breadcrumb ~logger ~accounts_with_secret_keys) )
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

    let%test_unit "after the timeout expires, the missing node still doesn't \
                   show up, so the catchup job is fired" =
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create Synchronous
      in
      let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create Synchronous
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier = setup_random_frontier () in
          let scheduler =
            Catchup_scheduler.create ~logger ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value
                 (gen_linear_breadcrumbs ~logger ~size:2
                    ~accounts_with_secret_keys randomly_chosen_breadcrumb)
          in
          let missing_hash =
            List.hd_exn upcoming_breadcrumbs
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.hash
          in
          let dangling_breadcrumb = List.nth_exn upcoming_breadcrumbs 1 in
          let dangling_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb
          in
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition ;
          let result_ivar = Ivar.create () in
          Strict_pipe.Reader.iter_without_pushback catchup_job_reader
            ~f:(fun catchup_hash -> Ivar.fill result_ivar catchup_hash )
          |> don't_wait_for ;
          let%map catchup_hash = Ivar.read result_ivar in
          assert (Coda_base.State_hash.equal missing_hash catchup_hash) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "if a linear sequence of transitions in reverse order, \
                   catchup scheduler should not create duplicate jobs" =
      let _catchup_job_reader, catchup_job_writer =
        Strict_pipe.create Synchronous
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create Synchronous
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier = setup_random_frontier () in
          let scheduler =
            Catchup_scheduler.create ~logger ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let size = 4 in
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value
                 (gen_linear_breadcrumbs ~logger ~size
                    ~accounts_with_secret_keys randomly_chosen_breadcrumb)
          in
          let upcoming_transitions =
            List.map ~f:Transition_frontier.Breadcrumb.transition_with_hash
              upcoming_breadcrumbs
          in
          let missing_breadcrumb = List.hd_exn upcoming_breadcrumbs in
          let missing_transition = List.hd_exn upcoming_transitions in
          let dangling_transitions = List.tl_exn upcoming_transitions in
          List.(
            iter (rev dangling_transitions) ~f:(fun transition ->
                Catchup_scheduler.watch scheduler ~timeout_duration ~transition ;
                assert (Catchup_scheduler.has_timeout scheduler transition) )) ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler
            ~hash:(With_hash.hash missing_transition)
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let%map received_rose_tree =
            extract_children_from ~reader:catchup_breadcrumbs_reader
              ~root:missing_breadcrumb
          in
          assert (
            List.equal
              (Rose_tree.flatten received_rose_tree)
              upcoming_breadcrumbs ~equal:Transition_frontier.Breadcrumb.equal
          ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "If a non-linear sequence of transitions out of order and \
                   the missing node is received before the timeout expires, \
                   the timeout would be canceled" =
      let _catchup_job_reader, catchup_job_writer =
        Strict_pipe.create Synchronous
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create Synchronous
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier = setup_random_frontier () in
          let scheduler =
            Catchup_scheduler.create ~logger ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let%bind upcoming_rose_tree =
            Rose_tree.Deferred.all
            @@ Quickcheck.random_value
                 (gen_tree ~logger ~size:5 ~accounts_with_secret_keys
                    randomly_chosen_breadcrumb)
          in
          let upcoming_breadcrumbs = Rose_tree.flatten upcoming_rose_tree in
          let upcoming_transitions =
            List.map ~f:Transition_frontier.Breadcrumb.transition_with_hash
              upcoming_breadcrumbs
          in
          let missing_breadcrumb = List.hd_exn upcoming_breadcrumbs in
          let missing_transition = List.hd_exn upcoming_transitions in
          let dangling_transitions = List.tl_exn upcoming_transitions in
          List.iter (List.permute dangling_transitions)
            ~f:(fun dangling_transition ->
              Catchup_scheduler.watch scheduler ~timeout_duration
                ~transition:dangling_transition ) ;
          assert (not @@ Catchup_scheduler.is_empty scheduler) ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler
            ~hash:(With_hash.hash missing_transition)
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let%map received_rose_tree =
            extract_children_from ~reader:catchup_breadcrumbs_reader
              ~root:missing_breadcrumb
          in
          assert (
            Rose_tree.equiv received_rose_tree upcoming_rose_tree
              ~f:Transition_frontier.Breadcrumb.equal ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )
  end )
