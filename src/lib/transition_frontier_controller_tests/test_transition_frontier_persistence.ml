open Async
open Core
open Coda_base
open Pipe_lib

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

module Transition_frontier_persistence =
Transition_frontier_persistence.Make (struct
  include Stubs
  module Make_worker = Transition_frontier_persistence.Worker.Make_async
  module Make_transition_storage =
    Transition_frontier_persistence.Transition_storage.Make
end)

let%test_module "Transition Frontier Persistence" =
  ( module struct
    let check_transitions ~logger transition_storage written_breadcrumbs =
      List.iter written_breadcrumbs ~f:(fun breadcrumb ->
          let open Transition_frontier_persistence in
          let {With_hash.hash; data= expected_transition} =
            Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
          in
          let queried_transition, _ =
            Transition_storage.get ~logger transition_storage
              (Transition_storage.Schema.Transition hash)
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
             Diff_mutant.E.t
             list)
           ->
          Deferred.List.fold diffs ~init:acc_hash ~f:(fun acc_hash -> function
            | E mutant_diff ->
                let%map new_hash =
                  Transition_frontier_persistence.For_tests
                  .write_diff_and_verify ~logger ~acc_hash worker frontier
                    mutant_diff
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

    let with_persistence ?directory_name ~logger ~f =
      let%bind frontier =
        create_root_frontier ~logger Genesis_ledger.accounts
      in
      let worker =
        Transition_frontier_persistence.create ~logger ?directory_name ()
      in
      let%map result = f (frontier, worker) in
      Transition_frontier_persistence.Worker.close worker ;
      result

    let with_database ~directory_name ~f =
      let database =
        Transition_frontier_persistence.Transition_storage.create
          ~directory:directory_name
      in
      let result = f database in
      Transition_frontier_persistence.Transition_storage.close database ;
      result

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
      let directory_name = Uuid.to_string (Uuid.create ()) in
      let%map breadcrumbs =
        with_persistence ~logger ~directory_name ~f:(fun (frontier, t) ->
            let%bind breadcrumbs =
              generate_breadcrumbs ~logger ~gen_root_breadcrumb_builder
                frontier num_breadcrumbs
            in
            let%map () = store_transitions ~logger t frontier breadcrumbs in
            breadcrumbs )
      in
      with_database ~directory_name ~f:(fun transition_storage ->
          check_transitions ~logger transition_storage breadcrumbs )

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
      let directory_name = Uuid.to_string (Uuid.create ()) in
      let%map root, next_breadcrumb =
        with_persistence ~logger ~directory_name ~f:(fun (frontier, t) ->
            let create_breadcrumb =
              gen_breadcrumb ~logger
                ~accounts_with_secret_keys:Genesis_ledger.accounts
              |> Quickcheck.random_value
            in
            let root = Transition_frontier.root frontier in
            let%map next_breadcrumb =
              create_breadcrumb (Deferred.return root)
            in
            let open Transition_frontier.Breadcrumb in
            Transition_frontier_persistence.Worker.handle_diff t
              Diff_hash.empty
              (E
                 (New_frontier
                    ( get_transition root
                    , staged_ledger root |> Staged_ledger.scan_state )))
            |> ignore ;
            Transition_frontier_persistence.Worker.handle_diff t
              Diff_hash.empty
              (E (Add_transition (get_transition next_breadcrumb)))
            |> ignore ;
            (root, next_breadcrumb) )
      in
      with_database ~directory_name ~f:(fun storage ->
          check_transitions ~logger storage [root; next_breadcrumb] )

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
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      let logger = Logger.create () in
      let num_breadcrumbs = max_length in
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let directory_name = Uuid.to_string (Uuid.create ()) in
      let%bind frontier =
        create_root_frontier ~logger Genesis_ledger.accounts
      in
      let worker =
        Transition_frontier_persistence.create ~logger ~directory_name ()
      in
      let%bind breadcrumbs =
        generate_breadcrumbs ~logger
          ~gen_root_breadcrumb_builder:gen_flattened_tree frontier
          num_breadcrumbs
      in
      let root_snarked_ledger =
        Transition_frontier.For_tests.root_snarked_ledger frontier
      in
      let%bind () = store_transitions ~logger worker frontier breadcrumbs in
      Transition_frontier_persistence.Worker.close worker ;
      let%map deserialized_frontier =
        Transition_frontier_persistence.deserialize ~directory_name ~logger
          ~root_snarked_ledger
          ~consensus_local_state:
            (Transition_frontier.consensus_local_state frontier)
      in
      Transition_frontier.equal frontier deserialized_frontier

    (* TODO: create a test where a batch of diffs are being applied, but the
       worker dies in the middle. The transition_frontier_database can be left
       in a bad state and it needs a way to recover from it. *)
  end )
