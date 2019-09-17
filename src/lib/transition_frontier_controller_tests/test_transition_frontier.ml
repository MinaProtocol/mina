open Core
open Async
open Coda_base

let%test_module "Root_history and Transition_frontier" =
  ( module struct
    let max_length = 5

    module Stubs = Stubs.Make (struct
      let max_length = max_length
    end)

    open Stubs

    let breadcrumbs_path = Transition_frontier.root_history_path_map ~f:Fn.id

    let accounts_with_secret_keys = Genesis_ledger.accounts

    let create_root_frontier = create_root_frontier accounts_with_secret_keys

    let create_breadcrumbs ~logger ~trust_system ~size root =
      Deferred.all
      @@ Quickcheck.random_value
           (gen_linear_breadcrumbs ~logger ~trust_system ~size
              ~accounts_with_secret_keys root)

    let breadcrumb_trail_equals =
      List.equal Transition_frontier.Breadcrumb.equal

    let logger = Logger.null ()

    let trust_system = Trust_system.null ()

    let%test "Should be able to find a breadcrumb in the transition frontier \
              after adding a valid external_transition" =
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier = create_root_frontier ~logger in
      let root = Transition_frontier.root frontier in
      let generate_breadcrumb =
        Quickcheck.random_value
          (gen_breadcrumb ~logger ~trust_system ~accounts_with_secret_keys)
      in
      let%bind next_breadcrumb = generate_breadcrumb (Deferred.return root) in
      let%map () =
        Transition_frontier.add_breadcrumb_exn frontier next_breadcrumb
      in
      let queried_breadcrumb =
        Transition_frontier.find_exn frontier
          (Transition_frontier.Breadcrumb.state_hash next_breadcrumb)
      in
      Transition_frontier.Breadcrumb.equal next_breadcrumb queried_breadcrumb

    let%test "Constructing a longer branch should change the best tip" =
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier = create_root_frontier ~logger in
      let root = Transition_frontier.root frontier in
      let generate_breadcrumb =
        Quickcheck.random_value
          (gen_breadcrumb ~logger ~trust_system ~accounts_with_secret_keys)
      in
      let%bind next_breadcrumb = generate_breadcrumb (Deferred.return root) in
      let%bind () =
        Transition_frontier.add_breadcrumb_exn frontier next_breadcrumb
      in
      let best_tip = Transition_frontier.best_tip frontier in
      assert (Transition_frontier.Breadcrumb.equal next_breadcrumb best_tip) ;
      let%bind longer_branch =
        create_breadcrumbs ~logger ~trust_system ~size:2 root
      in
      let%map () =
        Deferred.List.iter longer_branch ~f:(fun ancestor ->
            Transition_frontier.add_breadcrumb_exn frontier ancestor )
      in
      let expected_new_best_tip =
        Transition_frontier.Breadcrumb.state_hash
        @@ List.last_exn longer_branch
      in
      let new_best_tip =
        Transition_frontier.Breadcrumb.state_hash
        @@ Transition_frontier.best_tip frontier
      in
      State_hash.equal expected_new_best_tip new_best_tip

    let%test "Adding many transitions to the frontier should update the root \
              of the transition_frontier" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier = create_root_frontier ~logger in
      let root = Transition_frontier.root frontier in
      let%bind breadcrumbs =
        create_breadcrumbs ~logger ~trust_system ~size:(max_length + 1) root
      in
      let%bind small_fork_breadcrumbs1 =
        create_breadcrumbs ~logger ~trust_system ~size:(max_length / 2) root
      in
      let%bind small_fork_breadcrumbs2 =
        create_breadcrumbs ~logger ~trust_system ~size:(max_length / 2) root
      in
      let forking_breadcrumbs =
        small_fork_breadcrumbs1 @ small_fork_breadcrumbs2
      in
      let%bind () =
        Deferred.List.iter forking_breadcrumbs
          ~f:(Transition_frontier.add_breadcrumb_exn frontier)
      in
      let%map () =
        Deferred.List.iter breadcrumbs
          ~f:(Transition_frontier.add_breadcrumb_exn frontier)
      in
      assert (
        List.for_all forking_breadcrumbs ~f:(fun breadcrumb ->
            let state_hash =
              Transition_frontier.Breadcrumb.state_hash breadcrumb
            in
            Option.is_none @@ Transition_frontier.find frontier state_hash ) ) ;
      let new_root = Transition_frontier.root frontier in
      Transition_frontier.Breadcrumb.equal (List.hd_exn breadcrumbs) new_root

    let%test_unit "We apply diff on adding a breadcrumb and then setting that \
                   as our root" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier = create_root_frontier ~logger in
      let root = Transition_frontier.root frontier in
      let generate_breadcrumb =
        Quickcheck.random_value
          (gen_breadcrumb ~logger ~trust_system ~accounts_with_secret_keys)
      in
      let%bind next_breadcrumb = generate_breadcrumb (Deferred.return root) in
      let open Transition_frontier.Diff in
      let diffs =
        [ E.E (New_breadcrumb next_breadcrumb)
        ; E.E (Best_tip_changed next_breadcrumb)
        ; E (Root_transitioned {new_= next_breadcrumb; garbage= []}) ]
      in
      List.iter diffs ~f:(Transition_frontier.For_tests.apply_diff frontier) ;
      Deferred.unit

    let%test "The length of the longest branch in the transition_frontier \
              should be max_length" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier = create_root_frontier ~logger in
      let root = Transition_frontier.root frontier in
      let offset = 2 in
      let%bind breadcrumbs =
        create_breadcrumbs ~logger ~trust_system ~size:(max_length + offset)
          root
      in
      let%map () =
        Deferred.List.iter breadcrumbs
          ~f:(Transition_frontier.add_breadcrumb_exn frontier)
      in
      let breadcrumbs_path_to_root =
        Transition_frontier.path_map ~f:Fn.id frontier
          Transition_frontier.(best_tip frontier)
      in
      let expected_results = List.drop breadcrumbs offset in
      [%test_eq: int] ~message:"Expected best tip length to be max_length"
        ~equal:Int.equal max_length
        (List.length breadcrumbs_path_to_root) ;
      breadcrumb_trail_equals expected_results breadcrumbs_path_to_root

    let common_ancestor_test ancestor_length branch1_length branch2_length =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let root = Transition_frontier.root frontier in
          let%bind ancestors =
            create_breadcrumbs ~logger ~trust_system ~size:ancestor_length root
          in
          let youngest_ancestor = List.last_exn ancestors in
          let%bind () =
            Deferred.List.iter ancestors ~f:(fun ancestor ->
                Transition_frontier.add_breadcrumb_exn frontier ancestor )
          in
          let%bind branch1 =
            create_breadcrumbs ~logger ~trust_system ~size:branch1_length
              youngest_ancestor
          in
          let%bind branch2 =
            create_breadcrumbs ~logger ~trust_system ~size:branch2_length
              youngest_ancestor
          in
          let bc1, bc2 = (List.last_exn branch1, List.last_exn branch2) in
          let%map () =
            Deferred.List.iter (List.append branch1 branch2)
              ~f:(fun breadcrumb ->
                Transition_frontier.add_breadcrumb_exn frontier breadcrumb )
          in
          State_hash.equal
            (Transition_frontier.common_ancestor frontier bc1 bc2)
            (Transition_frontier.Breadcrumb.state_hash youngest_ancestor) )

    let%test "common_ancestor should find the youngest ancestor when two \
              branches have the same lengths" =
      let ancestor_length = max_length / 2 in
      common_ancestor_test ancestor_length
        (max_length - ancestor_length)
        (max_length - ancestor_length)

    let%test "common_ancestor should find the youngest ancestor when two \
              branches have randomized lengths" =
      let ancestor_length = max_length / 2 in
      common_ancestor_test ancestor_length
        (1 + Random.int (max_length - ancestor_length))
        (1 + Random.int (max_length - ancestor_length))

    let%test "If a transition does not exists in the transition_frontier or \
              in the root_history, then we should not get an answer" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let root = Transition_frontier.root frontier in
          let%bind breadcrumbs =
            create_breadcrumbs ~logger ~trust_system ~size:max_length root
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
          Option.is_none
            ( breadcrumbs_path frontier
            @@ Transition_frontier.Breadcrumb.state_hash last_breadcrumb ) )

    let%test "Query transition only from transition_frontier if the \
              root_history is empty" =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let root = Transition_frontier.root frontier in
          let%bind breadcrumbs =
            create_breadcrumbs ~logger ~trust_system ~size:max_length root
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
            |> Option.value_exn |> Non_empty_list.to_list
          in
          assert (Transition_frontier.For_tests.root_history_is_empty frontier) ;
          let expected_breadcrumbs =
            Transition_frontier.root frontier
            :: List.take breadcrumbs (random_index + 1)
          in
          breadcrumb_trail_equals expected_breadcrumbs queried_breadcrumbs )

    let%test "Query transitions only from root_history" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let root = Transition_frontier.root frontier in
          let query_index = 1 in
          let size = max_length + query_index + 2 in
          let%bind breadcrumbs =
            create_breadcrumbs ~logger ~trust_system ~size root
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
          List.equal Transition_frontier.Breadcrumb.equal expected_breadcrumbs
            ( breadcrumbs_path frontier query_hash
            |> Option.value_exn |> Non_empty_list.to_list ) )

    let%test "moving the root removes the old root's non-heir children as \
              garbage" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let%bind () =
            add_linear_breadcrumbs ~logger ~trust_system ~size:max_length
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
            add_child ~parent:(Transition_frontier.best_tip frontier)
          in
          Transition_frontier.(
            find frontier @@ Breadcrumb.state_hash soon_garbage)
          |> Option.is_none )

    let%test "Transitions get popped off from root history" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let root = Transition_frontier.root frontier in
          let root_hash = Transition_frontier.Breadcrumb.state_hash root in
          let size = (3 * max_length) + 1 in
          let%map () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:
                (gen_linear_breadcrumbs ~logger ~trust_system ~size
                   ~accounts_with_secret_keys)
          in
          assert (
            not
            @@ Transition_frontier.For_tests.root_history_mem frontier
                 root_hash ) ;
          Transition_frontier.find frontier root_hash |> Option.is_empty )

    let%test "Get transitions from both transition frontier and root history" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger in
          let root = Transition_frontier.root frontier in
          let num_root_history_breadcrumbs =
            Quickcheck.random_value (Int.gen_incl 1 (2 * max_length))
          in
          let%bind root_history_breadcrumbs =
            create_breadcrumbs ~logger ~trust_system
              ~size:num_root_history_breadcrumbs root
          in
          let most_recent_breadcrumb_in_root_history_breadcrumb =
            List.last_exn root_history_breadcrumbs
          in
          let%bind transition_frontier_breadcrumbs =
            create_breadcrumbs ~logger ~trust_system ~size:max_length
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
            |> Option.value_exn |> Non_empty_list.to_list
          in
          List.equal Transition_frontier.Breadcrumb.equal
            expected_breadcrumb_trail result )
  end )
