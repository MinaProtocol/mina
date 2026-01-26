(*
(* Only show stdout for failed inline tests. *)
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

    let hb_logger = Logger.null ()

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

(* Test for get_ancestry_proof function *)
open Core
open Async

let%test_module "get_ancestry_proof" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~logger
            ~proof_level:precomputed_values.proof_level
            ~constraint_constants:precomputed_values.constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            () )

    let gen_frontier ~max_length chain_size =
      let%map.Quickcheck.Generator frontier, branch =
        Transition_frontier.For_tests.gen_with_branch ~logger ~verifier
          ~precomputed_values ~max_length ~frontier_size:0
          ~branch_size:chain_size ()
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          Deferred.List.iter branch
            ~f:(Transition_frontier.add_breadcrumb_exn frontier) ) ;
      let best_tip = Transition_frontier.best_tip frontier in
      let target_state_hash =
        Transition_frontier.Breadcrumb.state_hash best_tip
      in
      let length b =
        Transition_frontier.Breadcrumb.consensus_state b
        |> Consensus.Data.Consensus_state.blockchain_length
        |> Unsigned.UInt32.to_int
      in
      let root_length = Transition_frontier.root frontier |> length in
      (frontier, target_state_hash, length best_tip - root_length + 1)

    let check_result ~proof_depth ~target_state_hash result =
      let init_state_hash, state_body_hashes = Or_error.ok_exn result in
      if List.length state_body_hashes <> proof_depth then
        failwithf
          "length of state_body_hashes %d is not equal to expected \
           proof_depth: %d"
          (List.length state_body_hashes)
          proof_depth () ;
      if
        Option.is_none
          (Transition_chain_verifier.verify ~target_hash:target_state_hash
             ~transition_chain_proof:(init_state_hash, state_body_hashes) )
      then failwith "Transition_chain_verifier.verify failed"

    let rec kth_ancestor ~frontier hash = function
      | 0 ->
          hash
      | k ->
          let parent_hash =
            Transition_frontier.find frontier hash
            |> Option.value_exn |> Transition_frontier.Breadcrumb.parent_hash
          in
          kth_ancestor ~frontier parent_hash (k - 1)

    let%test_unit "get_ancestry_proof returns valid proof" =
      let proof_depth = 4 in
      let chain_size = proof_depth + 3 in
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:10 chain_size)
        ~f:(fun (frontier, target_state_hash, length_to_root_parent) ->
          Transition_frontier.get_ancestry_proof frontier ~target_state_hash
            ~depth:proof_depth
          |> check_result
               ~proof_depth:(Int.min proof_depth length_to_root_parent)
               ~target_state_hash ;
          Transition_frontier.get_ancestry_proof frontier ~target_state_hash
          |> check_result ~proof_depth:length_to_root_parent ~target_state_hash )

    let%test_unit "get_ancestry_proof can access root history" =
      let max_length = 4 in
      let ancestors_to_drop = 3 in
      Quickcheck.test ~trials:1
        (gen_frontier ~max_length ((max_length * 2) + 3))
        ~f:(fun (frontier, best_tip_hash, length_to_root_parent) ->
          (* If the check below fails, it means the frontier is generated with a chain
             * that is too small. Try increasing the chain size parameter
             * of gen_frontier. *)
          if length_to_root_parent <> max_length + 1 then
            failwithf
              "length_to_root_parent %d should be equal to (max_length = %d) + \
               1"
              length_to_root_parent max_length () ;
          (* check that root history is more than ancestors_to_drop *)
          let root_history =
            Transition_frontier.(
              Extensions.get_extension (extensions frontier) Root_history)
          in
          if Extensions.Root_history.length root_history < ancestors_to_drop
          then
            failwithf
              "root_history length %d should be more than ancestors_to_drop %d"
              (Extensions.Root_history.length root_history)
              ancestors_to_drop () ;
          let target_state_hash =
            kth_ancestor ~frontier best_tip_hash ancestors_to_drop
          in
          Transition_frontier.get_ancestry_proof frontier ~target_state_hash
          |> check_result ~proof_depth:max_length ~target_state_hash )

    let%test_unit "get_ancestry_proof handles depth larger than chain correctly"
        =
      let proof_depth = 10 in
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:10 3)
        ~f:(fun (frontier, target_state_hash, length_to_root_parent) ->
          (* Get ancestry proof - should stop when reaching root *)
          Transition_frontier.get_ancestry_proof frontier ~target_state_hash
            ~depth:proof_depth
          |> check_result ~proof_depth:length_to_root_parent ~target_state_hash )

    let%test_unit "get_ancestry_proof handles non-best tip correctly" =
      let ancestors_to_drop = 2 in
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:10 10)
        ~f:(fun (frontier, best_tip_hash, length_to_root_parent) ->
          assert (length_to_root_parent - ancestors_to_drop >= 2) ;
          (* Getting great-parent of best tip *)
          let target_state_hash =
            kth_ancestor ~frontier best_tip_hash ancestors_to_drop
          in
          (* Get ancestry proof - should stop when reaching root *)
          Transition_frontier.get_ancestry_proof frontier ~target_state_hash
            ~depth:(length_to_root_parent - ancestors_to_drop + 1)
          |> check_result
               ~proof_depth:(length_to_root_parent - ancestors_to_drop)
               ~target_state_hash ;
          Transition_frontier.get_ancestry_proof frontier ~target_state_hash
            ~depth:2
          |> check_result ~proof_depth:2 ~target_state_hash )

    let%test_unit "get_ancestry_proof rejects negative depth" =
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:5 3)
        ~f:(fun (frontier, target_state_hash, _) ->
          (* Try with negative depth *)
          if
            Transition_frontier.get_ancestry_proof frontier ~target_state_hash
              ~depth:(-1)
            |> Or_error.is_ok
          then failwith "get_ancestry_proof should fail" )
  end )
