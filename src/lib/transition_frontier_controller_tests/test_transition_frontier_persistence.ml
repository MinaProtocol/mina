open Async
open Core
open Coda_base
open Pipe_lib

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

module Worker = struct
  include Transition_frontier_persistence.Worker.Make (Stubs)

  let handle_diff t acc_hash diff_mutant =
    Deferred.Or_error.return (handle_diff t acc_hash diff_mutant)
end

module Transition_frontier_persistence =
Transition_frontier_persistence.Make (struct
  include Stubs
  module Worker = Worker
end)

let%test_module "Transition Frontier Persistence" =
  ( module struct
    let check_transitions worker written_breadcrumbs =
      List.iter written_breadcrumbs ~f:(fun breadcrumb ->
          let open Worker.For_tests in
          let {With_hash.hash; data= expected_transition} =
            Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
          in
          let transition_storage = transition_storage worker in
          let queried_transition, _ =
            Transition_storage.get transition_storage
              ~key:(Transition_storage.Schema.Transition hash)
            |> Option.value_exn
          in
          assert (
            External_transition.(
              equal (of_verified expected_transition) queried_transition) ) )

    let store_transitions ~logger worker frontier breadcrumbs =
      let complete_ivar = Ivar.create () in
      let breadcrumb_jobs =
        State_hash.Hash_set.of_list
        @@ List.map ~f:Transition_frontier.Breadcrumb.state_hash breadcrumbs
      in
      let remove_job hash =
        Hash_set.remove breadcrumb_jobs hash ;
        if Hash_set.is_empty breadcrumb_jobs then Ivar.fill complete_ivar ()
      in
      Broadcast_pipe.Reader.fold
        (Transition_frontier.persistence_diff_pipe frontier)
        ~init:Diff_hash.empty
        ~f:(fun acc_hash
           (diffs :
             ( External_transition.Stable.Latest.t
             , State_hash.Stable.Latest.t )
             With_hash.t
             Diff_mutant.e
             list)
           ->
          Deferred.List.fold diffs ~init:acc_hash ~f:(fun acc_hash -> function
            | E mutant_diff ->
                let%map new_hash =
                  Transition_frontier_persistence.write_diff_and_verify ~logger
                    ~acc_hash worker frontier mutant_diff
                in
                ( match mutant_diff with
                | Add_transition {With_hash.hash; _} -> remove_job hash
                | New_frontier ({With_hash.hash; _}, _) -> remove_job hash
                | _ -> () ) ;
                new_hash ) )
      |> Deferred.ignore |> don't_wait_for ;
      let%bind () =
        Deferred.List.iter breadcrumbs
          ~f:(Transition_frontier.add_breadcrumb_exn frontier)
      in
      Ivar.read complete_ivar

    let store_and_check_transitions ~logger worker frontier breadcrumbs =
      let%map () = store_transitions ~logger worker frontier breadcrumbs in
      check_transitions worker breadcrumbs

    let create_worker ~logger =
      let%map frontier =
        create_root_frontier ~logger Genesis_ledger.accounts
      in
      let worker : Worker.t = Worker.create ~logger () in
      (frontier, worker)

    let generate_breadcrumbs ~logger ~gen_root_breadcrumb_builder frontier size
        =
      gen_root_breadcrumb_builder ~logger ~size
        ~accounts_with_secret_keys:Genesis_ledger.accounts
        (Transition_frontier.root frontier)
      |> Quickcheck.random_value |> Deferred.all

    let test_breadcrumbs ~gen_root_breadcrumb_builder num_breadcrumbs =
      let logger = Logger.create () in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier, worker = create_worker ~logger in
      let%bind breadcrumbs =
        generate_breadcrumbs ~logger ~gen_root_breadcrumb_builder frontier
          num_breadcrumbs
      in
      store_and_check_transitions ~logger worker frontier breadcrumbs

    let test_linear_breacrumbs =
      test_breadcrumbs ~gen_root_breadcrumb_builder:gen_linear_breadcrumbs

    let test_tree_breadcrumbs =
      test_breadcrumbs ~gen_root_breadcrumb_builder:gen_flattened_tree

    let get_transition =
      Fn.compose
        (With_hash.map ~f:External_transition.of_verified)
        Transition_frontier.Breadcrumb.transition_with_hash

    let%test_unit "For any key-value pair (k, v) among a set of homogenous \
                   key-value pairs, set(k, v); get(k)==v" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      let logger = Logger.create () in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier, worker = create_worker ~logger in
      let create_breadcrumb =
        gen_breadcrumb ~logger
          ~accounts_with_secret_keys:Genesis_ledger.accounts
        |> Quickcheck.random_value
      in
      let root = Transition_frontier.root frontier in
      let%map next_breadcrumb = create_breadcrumb (Deferred.return root) in
      let open Worker.For_tests in
      let transition_storage = transition_storage worker in
      let open Transition_frontier.Breadcrumb in
      Worker.handle_diff worker Diff_hash.empty
        (New_frontier
           (get_transition root, staged_ledger root |> Staged_ledger.scan_state))
      |> ignore ;
      Worker.handle_diff worker Diff_hash.empty
        (Add_transition (get_transition next_breadcrumb))
      |> ignore ;
      List.iter [root; next_breadcrumb] ~f:(fun breadcrumb ->
          let queried_transitions, _ =
            Transition_storage.get transition_storage
              ~key:
                (Transition
                   (Transition_frontier.Breadcrumb.state_hash breadcrumb))
            |> Option.value_exn
          in
          assert (
            External_transition.equal
              (get_transition breadcrumb |> With_hash.data)
              queried_transitions ) )

    let%test_unit "Dump external transitions to disk" =
      test_linear_breacrumbs 3

    let%test_unit "Root changes multiple times" =
      test_linear_breacrumbs (2 * max_length)

    let%test_unit "Randomly generate a tree" =
      test_tree_breadcrumbs (2 * max_length)

    let%test_unit "Randomly generate a tree" =
      test_tree_breadcrumbs (2 * max_length)

    let%test "Serializing a tree and then deserializing it should give us the \
              same transition_frontier" =
      let logger = Logger.create () in
      let num_breadcrumbs = 2 * max_length in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier, worker = create_worker ~logger in
      let%bind breadcrumbs =
        generate_breadcrumbs ~logger
          ~gen_root_breadcrumb_builder:gen_flattened_tree frontier
          num_breadcrumbs
      in
      let root_snarked_ledger =
        Transition_frontier.For_tests.root_snarked_ledger frontier
      in
      let%bind () = store_transitions ~logger worker frontier breadcrumbs in
      let%map deserialized_frontier =
        Worker.deserialize worker ~root_snarked_ledger
          ~consensus_local_state:
            (Transition_frontier.consensus_local_state frontier)
      in
      Transition_frontier.equal frontier deserialized_frontier

    (* TODO: create a test where a batch of diffs are being applied, but the
       worker dies in the middle. The transition_frontier_database can be left
       in a bad state and it needs a way to recover from it. *)
  end )
