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

    let%test_unit "before the timeout expires, the missing node is received \
                   by the scheduler, so the timeout would be canceled" =
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
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value ~size:2
                 (Quickcheck_lib.gen_imperative_list
                    ( randomly_chosen_breadcrumb |> return
                    |> Quickcheck.Generator.return )
                    (gen_breadcrumb ~logger ~accounts_with_secret_keys))
          in
          let missing_breadcrumb = List.nth_exn upcoming_breadcrumbs 0 in
          let missing_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              missing_breadcrumb
          in
          let dangling_breadcrumb = List.nth_exn upcoming_breadcrumbs 1 in
          let dangling_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb
          in
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler ~transition:missing_transition
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let result_ivar = Ivar.create () in
          Strict_pipe.Reader.iter_without_pushback catchup_breadcrumbs_reader
            ~f:(fun dangling_rose_trees ->
              Ivar.fill result_ivar dangling_rose_trees )
          |> don't_wait_for ;
          let%map dangling_rose_trees = Ivar.read result_ivar in
          let received_rose_tree =
            Rose_tree.T (missing_breadcrumb, dangling_rose_trees)
          in
          assert (
            Rose_tree.equal received_rose_tree
              (Rose_tree.of_list_exn upcoming_breadcrumbs)
              ~f:(fun breadcrumb1 breadcrumb2 ->
                External_transition.Verified.equal
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb1))
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb2)) ) ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

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
            @@ Quickcheck.random_value ~size:2
                 (Quickcheck_lib.gen_imperative_list
                    ( randomly_chosen_breadcrumb |> return
                    |> Quickcheck.Generator.return )
                    (gen_breadcrumb ~logger ~accounts_with_secret_keys))
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
            ~f:(fun catchup_transition ->
              Ivar.fill result_ivar catchup_transition )
          |> don't_wait_for ;
          let%map catchup_transition = Ivar.read result_ivar in
          assert (
            External_transition.Verified.equal
              (With_hash.data dangling_transition)
              (With_hash.data catchup_transition) ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "if a linear sequence of transitions come in order and the \
                   missing node is received before the timeout expires, the \
                   timeout would be canceled" =
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
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value ~size:4
                 (Quickcheck_lib.gen_imperative_list
                    ( randomly_chosen_breadcrumb |> return
                    |> Quickcheck.Generator.return )
                    (gen_breadcrumb ~logger ~accounts_with_secret_keys))
          in
          let missing_breadcrumb = List.nth_exn upcoming_breadcrumbs 0 in
          let dangling_breadcrumb1 = List.nth_exn upcoming_breadcrumbs 1 in
          let dangling_breadcrumb2 = List.nth_exn upcoming_breadcrumbs 2 in
          let dangling_breadcrumb3 = List.nth_exn upcoming_breadcrumbs 3 in
          let missing_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              missing_breadcrumb
          in
          let dangling_transition1 =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb1
          in
          let dangling_transition2 =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb2
          in
          let dangling_transition3 =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb3
          in
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition1 ;
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition2 ;
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition3 ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler ~transition:missing_transition
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let result_ivar = Ivar.create () in
          Strict_pipe.Reader.iter_without_pushback catchup_breadcrumbs_reader
            ~f:(fun dangling_rose_trees ->
              Ivar.fill result_ivar dangling_rose_trees )
          |> don't_wait_for ;
          let%map dangling_rose_trees = Ivar.read result_ivar in
          let received_rose_tree =
            Rose_tree.T (missing_breadcrumb, dangling_rose_trees)
          in
          assert (
            Rose_tree.equal received_rose_tree
              (Rose_tree.of_list_exn upcoming_breadcrumbs)
              ~f:(fun breadcrumb1 breadcrumb2 ->
                External_transition.Verified.equal
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb1))
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb2)) ) ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "if a linear sequence of transitions come out of order, \
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
          let%bind upcoming_breadcrumbs =
            Deferred.all
            @@ Quickcheck.random_value ~size:4
                 (Quickcheck_lib.gen_imperative_list
                    ( randomly_chosen_breadcrumb |> return
                    |> Quickcheck.Generator.return )
                    (gen_breadcrumb ~logger ~accounts_with_secret_keys))
          in
          let missing_breadcrumb = List.nth_exn upcoming_breadcrumbs 0 in
          let dangling_breadcrumb1 = List.nth_exn upcoming_breadcrumbs 1 in
          let dangling_breadcrumb2 = List.nth_exn upcoming_breadcrumbs 2 in
          let dangling_breadcrumb3 = List.nth_exn upcoming_breadcrumbs 3 in
          let missing_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              missing_breadcrumb
          in
          let dangling_transition1 =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb1
          in
          let dangling_transition2 =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb2
          in
          let dangling_transition3 =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb3
          in
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition3 ;
          assert (Catchup_scheduler.has_timeout scheduler dangling_transition3) ;
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition2 ;
          assert (
            Catchup_scheduler.has_timeout scheduler dangling_transition2
            && not
               @@ Catchup_scheduler.has_timeout scheduler dangling_transition3
          ) ;
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition1 ;
          assert (
            Catchup_scheduler.has_timeout scheduler dangling_transition1
            && not
               @@ Catchup_scheduler.has_timeout scheduler dangling_transition2
          ) ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler ~transition:missing_transition
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let result_ivar = Ivar.create () in
          Strict_pipe.Reader.iter_without_pushback catchup_breadcrumbs_reader
            ~f:(fun dangling_rose_trees ->
              Ivar.fill result_ivar dangling_rose_trees )
          |> don't_wait_for ;
          let%map dangling_rose_trees = Ivar.read result_ivar in
          let received_rose_tree =
            Rose_tree.T (missing_breadcrumb, dangling_rose_trees)
          in
          assert (
            Rose_tree.equal received_rose_tree
              (Rose_tree.of_list_exn upcoming_breadcrumbs)
              ~f:(fun breadcrumb1 breadcrumb2 ->
                External_transition.Verified.equal
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb1))
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb2)) ) ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )

    let%test_unit "If a non-linear sequence of transitions in order and the \
                   missing node is received before the timeout expires, the \
                   timeout would be canceled" =
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
            @@ Quickcheck.random_value ~size:5
                 (Quickcheck_lib.gen_imperative_rose_tree
                    ( randomly_chosen_breadcrumb |> return
                    |> Quickcheck.Generator.return )
                    (gen_breadcrumb ~logger ~accounts_with_secret_keys))
          in
          let upcoming_breadcrumbs = Rose_tree.flatten upcoming_rose_tree in
          let missing_breadcrumb = List.nth_exn upcoming_breadcrumbs 0 in
          let missing_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              missing_breadcrumb
          in
          let dangling_breadcrumbs = List.tl_exn upcoming_breadcrumbs in
          let dangling_transitions =
            List.map dangling_breadcrumbs
              ~f:Transition_frontier.Breadcrumb.transition_with_hash
          in
          List.iter (List.permute dangling_transitions)
            ~f:(fun dangling_transition ->
              Catchup_scheduler.watch scheduler ~timeout_duration
                ~transition:dangling_transition ) ;
          assert (not @@ Catchup_scheduler.is_empty scheduler) ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler ~transition:missing_transition
          |> ignore ;
          assert (Catchup_scheduler.is_empty scheduler) ;
          let result_ivar = Ivar.create () in
          Strict_pipe.Reader.iter_without_pushback catchup_breadcrumbs_reader
            ~f:(fun dangling_rose_trees ->
              Ivar.fill result_ivar dangling_rose_trees )
          |> don't_wait_for ;
          let%map dangling_rose_trees = Ivar.read result_ivar in
          let received_rose_tree =
            Rose_tree.T (missing_breadcrumb, dangling_rose_trees)
          in
          assert (
            Rose_tree.equiv received_rose_tree upcoming_rose_tree
              ~f:(fun breadcrumb1 breadcrumb2 ->
                External_transition.Verified.equal
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb1))
                  (With_hash.data
                     (Transition_frontier.Breadcrumb.transition_with_hash
                        breadcrumb2)) ) ) ;
          Strict_pipe.Writer.close catchup_breadcrumbs_writer ;
          Strict_pipe.Writer.close catchup_job_writer )
  end )
