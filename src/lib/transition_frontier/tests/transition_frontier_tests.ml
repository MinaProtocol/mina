(*
(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core
open Async
open Mina_base

let%test_module "Root_history and Transition_frontier" =
  ( module struct
    let max_length = 5

    module Stubs = Stubs.Make (struct
      let max_length = max_length
    end)

    open Stubs

    let breadcrumbs_path = Transition_frontier.root_history_path_map ~f:Fn.id

    let accounts_with_secret_keys = Test_genesis_ledger.accounts

    let create_root_frontier = create_root_frontier accounts_with_secret_keys

    let create_breadcrumbs ~logger ~pids ~trust_system ~size root =
      Deferred.all
      @@ Quickcheck.random_value
           (gen_linear_breadcrumbs ~logger ~pids ~trust_system ~size
              ~accounts_with_secret_keys root)

    let breadcrumb_trail_equals =
      List.equal Transition_frontier.Breadcrumb.equal

    let logger = Logger.null ()

    let hb_logger = Logger.create ()

    let pids = Child_processes.Termination.create_pid_table ()

    let trust_system = Trust_system.null ()

    let%test "If a transition does not exists in the transition_frontier or \
              in the root_history, then we should not get an answer" =
      heartbeat_flag := true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind frontier = create_root_frontier ~logger ~pids in
          let root = Transition_frontier.root frontier in
          let%bind breadcrumbs =
            create_breadcrumbs ~logger ~pids ~trust_system ~size:max_length
              root
          in
          let last_breadcrumb, breadcrumbs_to_add =
            let rev_breadcrumbs = List.rev breadcrumbs in
            ( List.hd_exn rev_breadcrumbs
            , List.rev @@ List.tl_exn rev_breadcrumbs )
          in
          let%map () =
            Deferred.List.iter breadcrumbs_to_add ~f:(fun breadcrumb ->
                Transition_frontier.add_breadcrumb_exn frontier breadcrumb )
          in
          let res =
            Option.is_none
              ( breadcrumbs_path frontier
              @@ Transition_frontier.Breadcrumb.state_hash last_breadcrumb )
          in
          heartbeat_flag := false ;
          res )

    let%test "Query transition only from transition_frontier if the \
              root_history is empty" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind frontier = create_root_frontier ~logger ~pids in
          let root = Transition_frontier.root frontier in
          let%bind breadcrumbs =
            create_breadcrumbs ~logger ~pids ~trust_system ~size:max_length
              root
          in
          let%map () =
            Deferred.List.iter breadcrumbs
              ~f:(Transition_frontier.add_breadcrumb_exn frontier)
          in
          let random_index =
            Quickcheck.random_value (Int.gen_incl 0 (max_length - 1))
          in
          let random_breadcrumb = List.(nth_exn breadcrumbs random_index) in
          let queried_breadcrumbs =
            breadcrumbs_path frontier
            @@ Transition_frontier.Breadcrumb.state_hash random_breadcrumb
            |> Option.value_exn |> Nonempty_list.to_list
          in
          assert (Transition_frontier.For_tests.root_history_is_empty frontier) ;
          let expected_breadcrumbs =
            Transition_frontier.root frontier
            :: List.take breadcrumbs (random_index + 1)
          in
          heartbeat_flag := false ;
          breadcrumb_trail_equals expected_breadcrumbs queried_breadcrumbs )

    let%test "Query transitions only from root_history" =
      heartbeat_flag := true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind frontier = create_root_frontier ~logger ~pids in
          let root = Transition_frontier.root frontier in
          let query_index = 1 in
          let size = max_length + query_index + 2 in
          let%bind breadcrumbs =
            create_breadcrumbs ~logger ~pids ~trust_system ~size root
          in
          let%map () =
            Deferred.List.iter breadcrumbs ~f:(fun breadcrumb ->
                Transition_frontier.add_breadcrumb_exn frontier breadcrumb )
          in
          let query_breadcrumb = List.nth_exn breadcrumbs query_index in
          let expected_breadcrumbs =
            root :: List.take breadcrumbs (query_index + 1)
          in
          let query_hash =
            Transition_frontier.Breadcrumb.state_hash query_breadcrumb
          in
          assert (
            Transition_frontier.For_tests.root_history_mem frontier query_hash
          ) ;
          heartbeat_flag := false ;
          List.equal Transition_frontier.Breadcrumb.equal expected_breadcrumbs
            ( breadcrumbs_path frontier query_hash
            |> Option.value_exn |> Nonempty_list.to_list ) )

    let%test "moving the root removes the old root's non-heir children as \
              garbage" =
      heartbeat_flag := true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind frontier = create_root_frontier ~logger ~pids in
          let%bind () =
            add_linear_breadcrumbs ~logger ~pids ~trust_system ~size:max_length
              ~accounts_with_secret_keys ~frontier
              ~parent:(Transition_frontier.root frontier)
          in
          let add_child =
            add_child ~logger ~trust_system ~accounts_with_secret_keys
              ~frontier
          in
          let%bind soon_garbage =
            add_child ~parent:(Transition_frontier.root frontier)
          in
          let%map _ =
            add_child ~parent:(Transition_frontier.best_tip frontier) ~pids
          in
          let res =
            Transition_frontier.(
              find frontier @@ Breadcrumb.state_hash soon_garbage)
            |> Option.is_none
          in
          heartbeat_flag := false ;
          res )

    let%test "Transitions get popped off from root history" =
      heartbeat_flag := true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind frontier = create_root_frontier ~logger ~pids in
          let root = Transition_frontier.root frontier in
          let root_hash = Transition_frontier.Breadcrumb.state_hash root in
          let size = (3 * max_length) + 1 in
          let%map () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:
                (gen_linear_breadcrumbs ~logger ~pids ~trust_system ~size
                   ~accounts_with_secret_keys)
          in
          assert (
            not
            @@ Transition_frontier.For_tests.root_history_mem frontier
                 root_hash ) ;
          let res =
            Transition_frontier.find frontier root_hash |> Option.is_empty
          in
          heartbeat_flag := false ;
          res )

    let%test "Get transitions from both transition frontier and root history" =
      heartbeat_flag := true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind frontier = create_root_frontier ~logger ~pids in
          let root = Transition_frontier.root frontier in
          let num_root_history_breadcrumbs =
            Quickcheck.random_value (Int.gen_incl 1 (2 * max_length))
          in
          let%bind root_history_breadcrumbs =
            create_breadcrumbs ~logger ~pids ~trust_system
              ~size:num_root_history_breadcrumbs root
          in
          let most_recent_breadcrumb_in_root_history_breadcrumb =
            List.last_exn root_history_breadcrumbs
          in
          let%bind transition_frontier_breadcrumbs =
            create_breadcrumbs ~logger ~pids ~trust_system ~size:max_length
              most_recent_breadcrumb_in_root_history_breadcrumb
          in
          let random_breadcrumb_index =
            Quickcheck.random_value (Int.gen_incl 0 (max_length - 1))
          in
          let random_breadcrumb_hash =
            Transition_frontier.Breadcrumb.state_hash
              (List.nth_exn transition_frontier_breadcrumbs
                 random_breadcrumb_index)
          in
          let expected_breadcrumb_trail =
            (root :: root_history_breadcrumbs)
            @ List.take transition_frontier_breadcrumbs
                (random_breadcrumb_index + 1)
          in
          let%map () =
            Deferred.List.iter
              (root_history_breadcrumbs @ transition_frontier_breadcrumbs)
              ~f:(fun breadcrumb ->
                Transition_frontier.add_breadcrumb_exn frontier breadcrumb )
          in
          let result =
            breadcrumbs_path frontier random_breadcrumb_hash
            |> Option.value_exn |> Nonempty_list.to_list
          in
          heartbeat_flag := false ;
          List.equal Transition_frontier.Breadcrumb.equal
            expected_breadcrumb_trail result )
  end )
*)
