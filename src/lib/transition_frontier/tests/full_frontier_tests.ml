(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Async_kernel
open Core_kernel
open Mina_base
open Frontier_base
open Deferred.Let_syntax
open Full_frontier.For_tests

let%test_module "Full_frontier tests" =
  ( module struct
    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let verifier = verifier ()

    let add_breadcrumb frontier breadcrumb =
      let diffs = Full_frontier.calculate_diffs frontier breadcrumb in
      ignore
        ( Full_frontier.apply_diffs frontier diffs ~has_long_catchup_job:false
            ~enable_epoch_ledger_sync:`Disabled
          : [ `New_root_and_diffs_with_mutants of
              Root_identifier.t option * Diff.Full.With_mutant.t list ] )

    let add_breadcrumbs frontier = List.iter ~f:(add_breadcrumb frontier)

    let%test_unit "Should be able to find a breadcrumbs after adding them" =
      Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:4
        ~f:(fun make_breadcrumb ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let frontier = create_frontier () in
              let root = Full_frontier.root frontier in
              let%map breadcrumb = make_breadcrumb root in
              add_breadcrumb frontier breadcrumb ;
              let queried_breadcrumb =
                Full_frontier.find_exn frontier
                  (Breadcrumb.state_hash breadcrumb)
              in
              [%test_eq: Breadcrumb.t] breadcrumb queried_breadcrumb ;
              clean_up_persistent_root ~frontier ) )

    let%test_unit "Constructing a better branch should change the best tip" =
      let gen_branches =
        let open Quickcheck.Generator.Let_syntax in
        let%bind short_branch = gen_breadcrumb_seq ~verifier 2 in
        let%map long_branch = gen_breadcrumb_seq ~verifier 3 in
        (short_branch, long_branch)
      in
      Quickcheck.test gen_branches ~trials:4
        ~f:(fun (make_short_branch, make_long_branch) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let frontier = create_frontier () in
              let test_best_tip ?message breadcrumb =
                [%test_eq: State_hash.t] ?message
                  (Breadcrumb.state_hash breadcrumb)
                  (Breadcrumb.state_hash @@ Full_frontier.best_tip frontier)
              in
              let root = Full_frontier.root frontier in
              let%bind short_branch = make_short_branch root in
              let%map long_branch = make_long_branch root in
              test_best_tip root ~message:"best tip should start as root" ;
              add_breadcrumbs frontier short_branch ;
              test_best_tip
                (List.last_exn short_branch)
                ~message:"best tip should change when short branch is added" ;
              add_breadcrumb frontier (List.hd_exn long_branch) ;
              test_best_tip
                (List.last_exn short_branch)
                ~message:
                  "best tip should not change when only part of long branch is \
                   added" ;
              add_breadcrumbs frontier (List.tl_exn long_branch) ;
              test_best_tip
                (List.last_exn long_branch)
                ~message:"best tip should change when all of best tip is added" ;
              clean_up_persistent_root ~frontier ) )

    let%test_unit "The root should be updated after (> max_length) nodes are \
                   added in sequence" =
      let test_eq ?message = [%test_eq: Breadcrumb.t] ?equal:None ?message in
      let test_not_eq ?message =
        let message = Option.map message ~f:(fun m -> "not " ^ m) in
        [%test_eq: Breadcrumb.t] ?message ~equal:(fun a b ->
            not (Breadcrumb.equal a b) )
      in
      Quickcheck.test
        (gen_breadcrumb_seq ~verifier (max_length * 2))
        ~trials:4
        ~f:(fun make_seq ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let frontier = create_frontier () in
              let root = Full_frontier.root frontier in
              let%map seq = make_seq root in
              ignore
              @@ List.fold seq ~init:1 ~f:(fun i breadcrumb ->
                     let pre_root = Full_frontier.root frontier in
                     add_breadcrumb frontier breadcrumb ;
                     let post_root = Full_frontier.root frontier in
                     if i > max_length then
                       test_not_eq pre_root post_root
                         ~message:
                           "roots should be different after max_length \
                            breadcrumbs are added"
                     else
                       test_eq pre_root post_root
                         ~message:
                           "roots should be the same before max_length \
                            breadcrumbs" ;
                     i + 1 ) ;
              clean_up_persistent_root ~frontier ) )

    let%test_unit "Protocol states are available for every transaction in the \
                   frontier" =
      Quickcheck.test
        (gen_breadcrumb_seq ~verifier (max_length * 4))
        ~trials:2
        ~f:(fun make_seq ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let frontier = create_frontier () in
              let root = Full_frontier.root frontier in
              let%map rest = make_seq root in
              List.iter rest ~f:(fun breadcrumb ->
                  add_breadcrumb frontier breadcrumb ;
                  let required_state_hashes =
                    Breadcrumb.staged_ledger breadcrumb
                    |> Staged_ledger.scan_state
                    |> Staged_ledger.Scan_state.required_state_hashes
                  in
                  List.iter (State_hash.Set.to_list required_state_hashes)
                    ~f:(fun hash ->
                      ignore
                        ( Full_frontier.For_tests.find_protocol_state_exn
                            frontier hash
                          : Mina_state.Protocol_state.value ) ) ) ;
              clean_up_persistent_root ~frontier ) )

    let%test_unit "The length of the longest branch should never be greater \
                   than max_length" =
      let gen =
        Quickcheck.Generator.Let_syntax.(
          Int.gen_incl max_length (max_length * 2)
          >>= gen_breadcrumb_seq ~verifier)
      in
      Quickcheck.test gen ~trials:4 ~f:(fun make_seq ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let frontier = create_frontier () in
              let root = Full_frontier.root frontier in
              let%map breadcrumbs = make_seq root in
              List.iter breadcrumbs ~f:(fun b ->
                  add_breadcrumb frontier b ;
                  [%test_pred: int] (( >= ) max_length)
                    (List.length
                       Full_frontier.(
                         path_map frontier (best_tip frontier) ~f:Fn.id) ) ) ;
              clean_up_persistent_root ~frontier ) )

    let%test_unit "Common ancestor can be reliably found" =
      let ancestor_length = (max_length / 2) - 1 in
      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%bind ancestors = gen_breadcrumb_seq ~verifier ancestor_length in
        let%bind branch_a =
          Int.gen_incl 1 (max_length / 2) >>= gen_breadcrumb_seq ~verifier
        in
        let%map branch_b =
          Int.gen_incl 1 (max_length / 2) >>= gen_breadcrumb_seq ~verifier
        in
        (ancestors, branch_a, branch_b)
      in
      Quickcheck.test gen ~trials:4
        ~f:(fun (make_ancestors, make_branch_a, make_branch_b) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let frontier = create_frontier () in
              let root = Full_frontier.root frontier in
              let%bind ancestors = make_ancestors root in
              let youngest_ancestor = List.last_exn ancestors in
              let%bind branch_a = make_branch_a youngest_ancestor in
              let%map branch_b = make_branch_b youngest_ancestor in
              let tip_a, tip_b =
                (List.last_exn branch_a, List.last_exn branch_b)
              in
              add_breadcrumbs frontier ancestors ;
              add_breadcrumbs frontier (branch_a @ branch_b) ;
              [%test_eq: State_hash.t]
                (Full_frontier.common_ancestor frontier tip_a tip_b)
                (Breadcrumb.state_hash youngest_ancestor) ;
              clean_up_persistent_root ~frontier ) )
  end )
