open Async
open Coda_base
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

    let catchup_job_reader, catchup_job_writer = Strict_pipe.create Synchronous

    let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
      Strict_pipe.create Synchronous

    let timeout_duration = Time.Span.of_ms 200L

    let accounts_with_secret_keys = Genesis_ledger.accounts

    let num_breadcrumbs = 5

    let%test_unit "before the timeout expires, the missing node is received \
                   by the scheduler, so the timeout would be canceled" =
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier =
            create_root_frontier ~logger accounts_with_secret_keys
          in
          let%bind _ : unit =
            build_frontier_randomly
              ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
                Quickcheck.Generator.with_size ~size:num_breadcrumbs
                @@ Quickcheck_lib.gen_imperative_ktree
                     (root_breadcrumb |> return |> Quickcheck.Generator.return)
                     (gen_breadcrumb ~logger ~accounts_with_secret_keys) )
              frontier
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let upcoming_breadcrumbs =
            Quickcheck.random_value ~size:2
              (Quickcheck_lib.gen_imperative_list
                 ( randomly_chosen_breadcrumb |> return
                 |> Quickcheck.Generator.return )
                 (gen_breadcrumb ~logger ~accounts_with_secret_keys))
          in
          let%bind missing_breadcrumb = List.hd_exn upcoming_breadcrumbs in
          let missing_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              missing_breadcrumb
          in
          assert (
            State_hash.equal
              ( With_hash.data missing_transition
              |> External_transition.Verified.protocol_state
              |> Protocol_state.previous_state_hash )
              ( With_hash.hash
              @@ Transition_frontier.Breadcrumb.transition_with_hash
                   randomly_chosen_breadcrumb ) ) ;
          let%bind dangling_breadcrumb =
            List.hd_exn (List.tl_exn upcoming_breadcrumbs)
          in
          let dangling_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb
          in
          let scheduler =
            Catchup_scheduler.create ~logger ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
          in
          Catchup_scheduler.watch scheduler ~timeout_duration
            ~transition:dangling_transition ;
          Transition_frontier.add_breadcrumb_exn frontier missing_breadcrumb ;
          Catchup_scheduler.notify scheduler ~transition:missing_transition
          |> ignore ;
          assert (not @@ Catchup_scheduler.mem scheduler dangling_transition) ;
          return () )

    let%test_unit "after the timeout expires, the missing node still doesn't \
                   show up, so the catchup job is fired" =
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let%bind frontier =
            create_root_frontier ~logger accounts_with_secret_keys
          in
          let%bind _ : unit =
            build_frontier_randomly
              ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
                Quickcheck.Generator.with_size ~size:num_breadcrumbs
                @@ Quickcheck_lib.gen_imperative_ktree
                     (root_breadcrumb |> return |> Quickcheck.Generator.return)
                     (gen_breadcrumb ~logger ~accounts_with_secret_keys) )
              frontier
          in
          let randomly_chosen_breadcrumb =
            Transition_frontier.all_breadcrumbs frontier
            |> List.permute |> List.hd_exn
          in
          let upcoming_breadcrumbs =
            Quickcheck.random_value ~size:2
              (Quickcheck_lib.gen_imperative_list
                 ( randomly_chosen_breadcrumb |> return
                 |> Quickcheck.Generator.return )
                 (gen_breadcrumb ~logger ~accounts_with_secret_keys))
          in
          let%bind dangling_breadcrumb =
            List.hd_exn (List.tl_exn upcoming_breadcrumbs)
          in
          let dangling_transition =
            Transition_frontier.Breadcrumb.transition_with_hash
              dangling_breadcrumb
          in
          let scheduler =
            Catchup_scheduler.create ~logger ~frontier ~time_controller
              ~catchup_job_writer ~catchup_breadcrumbs_writer
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
            State_hash.equal
              (With_hash.hash dangling_transition)
              (With_hash.hash catchup_transition) ) )
  end )
