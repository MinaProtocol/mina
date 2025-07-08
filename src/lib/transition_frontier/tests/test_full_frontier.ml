(* Testing
   -------

   Component: Transition Frontier / Full Frontier
   Subject: Test full frontier functionality
   Invocation: dune exec src/lib/transition_frontier/tests/alcotest/test_full_frontier.exe
*)

open Async_kernel
open Core_kernel
open Mina_base
open Frontier_base
open Deferred.Let_syntax
open Full_frontier.For_tests

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

let test_eq ~message b1 b2 =
  if not @@ Breadcrumb.equal b1 b2 then failwith message

let test_not_eq ~message b1 b2 = if Breadcrumb.equal b1 b2 then failwith message

let test_find_breadcrumbs_after_adding () =
  Alcotest.(check unit)
    "Should be able to find breadcrumbs after adding them" ()
    (Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:4
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
             test_eq ~message:"retrieved unexpected benchmark from frontier"
               breadcrumb queried_breadcrumb ;
             clean_up_persistent_root ~frontier ) ) )

let test_better_branch_changes_best_tip () =
  let gen_branches =
    let open Quickcheck.Generator.Let_syntax in
    let%bind short_branch = gen_breadcrumb_seq ~verifier 2 in
    let%map long_branch = gen_breadcrumb_seq ~verifier 3 in
    (short_branch, long_branch)
  in
  Alcotest.(check unit)
    "Constructing a better branch should change the best tip" ()
    (Quickcheck.test gen_branches ~trials:4
       ~f:(fun (make_short_branch, make_long_branch) ->
         Async.Thread_safe.block_on_async_exn (fun () ->
             let frontier = create_frontier () in
             let test_best_tip ?message breadcrumb =
               let expected = Breadcrumb.state_hash breadcrumb in
               let actual =
                 Breadcrumb.state_hash @@ Full_frontier.best_tip frontier
               in
               if not (State_hash.equal expected actual) then
                 failwith (Option.value message ~default:"best tip mismatch")
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
             clean_up_persistent_root ~frontier ) ) )

let test_root_update_after_max_length () =
  Alcotest.(check unit)
    "The root should be updated after (> max_length) nodes are added in \
     sequence"
    ()
    (Quickcheck.test
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
             clean_up_persistent_root ~frontier ) ) )

let test_protocol_states_available () =
  Alcotest.(check unit)
    "Protocol states are available for every transaction in the frontier" ()
    (Quickcheck.test
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
             clean_up_persistent_root ~frontier ) ) )

let test_longest_branch_length () =
  let gen =
    Quickcheck.Generator.Let_syntax.(
      Int.gen_incl max_length (max_length * 2) >>= gen_breadcrumb_seq ~verifier)
  in
  Alcotest.(check unit)
    "The length of the longest branch should never be greater than max_length"
    ()
    (Quickcheck.test gen ~trials:4 ~f:(fun make_seq ->
         Async.Thread_safe.block_on_async_exn (fun () ->
             let frontier = create_frontier () in
             let root = Full_frontier.root frontier in
             let%map breadcrumbs = make_seq root in
             List.iter breadcrumbs ~f:(fun b ->
                 add_breadcrumb frontier b ;
                 let path_length =
                   List.length
                     Full_frontier.(
                       path_map frontier (best_tip frontier) ~f:Fn.id)
                 in
                 if path_length > max_length then
                   failwithf "Path length %d exceeds max_length %d" path_length
                     max_length () ) ;
             clean_up_persistent_root ~frontier ) ) )

let test_common_ancestor () =
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
  Alcotest.(check unit)
    "Common ancestor can be reliably found" ()
    (Quickcheck.test gen ~trials:4
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
             let expected = Breadcrumb.state_hash youngest_ancestor in
             let actual = Full_frontier.common_ancestor frontier tip_a tip_b in
             if not (State_hash.equal expected actual) then
               failwith "Common ancestor mismatch" ;
             clean_up_persistent_root ~frontier ) ) )

let () =
  let open Alcotest in
  run "Full Frontier Tests"
    [ ( "Full frontier functionality"
      , [ test_case "find breadcrumbs after adding" `Quick
            test_find_breadcrumbs_after_adding
        ; test_case "better branch changes best tip" `Quick
            test_better_branch_changes_best_tip
        ; test_case "root update after max length" `Quick
            test_root_update_after_max_length
        ; test_case "protocol states available" `Quick
            test_protocol_states_available
        ; test_case "longest branch length constraint" `Quick
            test_longest_branch_length
        ; test_case "common ancestor finding" `Quick test_common_ancestor
        ] )
    ]
