open Async
open Core
open Pipe_lib
open Coda_transition

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs
module Transition_storage =
  Transition_frontier_persistence.Components.Transition_storage.Make (Stubs)

module Transition_frontier_persistence =
Transition_frontier_persistence.Make (struct
  include Stubs
  module Make_worker =
    Transition_frontier_persistence.Components.Worker.Make_async
  module Transition_storage = Transition_storage
end)

let%test_module "Transition Frontier Persistence" =
  ( module struct
    let logger = Logger.create ()

    let pids = Child_processes.Termination.create_pid_set ()

    let trust_system = Trust_system.null ()

    let check_transitions transition_storage written_breadcrumbs =
      List.iter written_breadcrumbs ~f:(fun breadcrumb ->
          let expected_transition =
            Transition_frontier.Breadcrumb.validated_transition breadcrumb
          in
          let queried_transition, _ =
            Transition_storage.get ~logger transition_storage
              (Transition_storage.Schema.Transition
                 (External_transition.Validated.state_hash expected_transition))
          in
          [%test_eq: External_transition.Validated.t] expected_transition
            queried_transition )

    let create_persistence ~directory_name =
      Transition_frontier_persistence.create ~logger ?directory_name
        ~flush_capacity:30 ~max_buffer_capacity:120 ()

    let store_transitions frontier breadcrumbs =
      Deferred.List.iter breadcrumbs
        ~f:(Transition_frontier.add_breadcrumb_exn frontier)

    let with_persistence ?directory_name ~logger ~pids ~f =
      let%bind frontier =
        create_root_frontier ~logger ~pids Genesis_ledger.accounts
      in
      Monitor.try_with (fun () ->
          let frontier_persistence = create_persistence ~directory_name in
          let%bind result = f (frontier, frontier_persistence) in
          let%map () =
            Transition_frontier_persistence.close_and_finish_copy
              frontier_persistence
          in
          result )
      |> Deferred.map ~f:(function
           | Ok value ->
               value
           | Error exn ->
               Logger.error ~module_:__MODULE__ ~location:__LOC__ logger
                 "Exception when persisting transition frontier: $exn. \
                  Creating frontier visualization"
                 ~metadata:[("exn", `String (Exn.to_string exn))] ;
               Transition_frontier.visualize ~filename:"frontier.dot" frontier ;
               raise exn )

    let generate_breadcrumbs ~gen_root_breadcrumb_builder frontier size =
      gen_root_breadcrumb_builder ~logger ~pids ~trust_system ~size
        ~accounts_with_secret_keys:Genesis_ledger.accounts
        (Transition_frontier.root frontier)
      |> Quickcheck.random_value |> Deferred.all

    let test_breadcrumbs ~gen_root_breadcrumb_builder num_breadcrumbs =
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let directory_name = Uuid.to_string (Uuid_unix.create ()) in
      let%map breadcrumbs =
        with_persistence ~logger ~pids ~directory_name ~f:(fun (frontier, t) ->
            let%bind breadcrumbs =
              generate_breadcrumbs ~gen_root_breadcrumb_builder frontier
                num_breadcrumbs
            in
            let reader_frontier, _ = Broadcast_pipe.create (Some frontier) in
            don't_wait_for
            @@ Transition_frontier_persistence
               .listen_to_frontier_broadcast_pipe reader_frontier t ;
            let%map () = store_transitions frontier breadcrumbs in
            breadcrumbs )
      in
      Transition_frontier_persistence.with_database ~directory_name
        ~f:(fun transition_storage ->
          return @@ check_transitions transition_storage breadcrumbs )

    let test_linear_breadcrumbs =
      test_breadcrumbs ~gen_root_breadcrumb_builder:gen_linear_breadcrumbs

    let test_tree_breadcrumbs =
      test_breadcrumbs ~gen_root_breadcrumb_builder:gen_tree_list

    let%test_unit "Should be able to query transitions from \
                   transition_storage after writing New_frontier and \
                   Add_transition diffs into the storage" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let directory_name = Uuid.to_string (Uuid_unix.create ()) in
      let%bind root, next_breadcrumb =
        with_persistence ~logger ~pids ~directory_name ~f:(fun (frontier, t) ->
            let create_breadcrumb =
              gen_breadcrumb ~logger ~pids ~trust_system
                ~accounts_with_secret_keys:Genesis_ledger.accounts
              |> Quickcheck.random_value
            in
            let root = Transition_frontier.root frontier in
            let%map next_breadcrumb =
              create_breadcrumb (Deferred.return root)
            in
            let staged_ledger =
              Transition_frontier.Breadcrumb.staged_ledger root
            in
            Transition_frontier_persistence.Worker.handle_diff t.worker
              Transition_frontier.Diff.Hash.empty
              (E
                 (New_frontier
                    Transition_frontier.Diff.Mutant.Root.Poly.
                      { root=
                          Transition_frontier.Breadcrumb.validated_transition
                            root
                      ; scan_state= Staged_ledger.scan_state staged_ledger
                      ; pending_coinbase=
                          Staged_ledger.pending_coinbase_collection
                            staged_ledger }))
            |> ignore ;
            Transition_frontier_persistence.Worker.handle_diff t.worker
              Transition_frontier.Diff.Hash.empty
              (E
                 (Add_transition
                    (Transition_frontier.Breadcrumb.validated_transition
                       next_breadcrumb)))
            |> ignore ;
            (root, next_breadcrumb) )
      in
      Transition_frontier_persistence.with_database ~directory_name
        ~f:(fun storage ->
          return @@ check_transitions storage [root; next_breadcrumb] )

    let%test_unit "Dump external transitions to disk" =
      Thread_safe.block_on_async_exn (fun () ->
          test_linear_breadcrumbs (max_length - 1) )

    let%test_unit "Root changes multiple times" =
      Printexc.record_backtrace true ;
      Thread_safe.block_on_async_exn (fun () ->
          test_linear_breadcrumbs (2 * max_length) )

    let%test_unit "Randomly generate a tree" =
      Thread_safe.block_on_async_exn (fun () ->
          test_tree_breadcrumbs (2 * max_length) )

    let test_deserialization num_breadcrumbs frontier =
      let directory_name = Uuid.to_string (Uuid_unix.create ()) in
      let frontier_reader, _ = Broadcast_pipe.create (Some frontier) in
      let frontier_persistence =
        create_persistence ~directory_name:(Some directory_name)
      in
      let%bind breadcrumbs =
        generate_breadcrumbs ~gen_root_breadcrumb_builder:gen_tree_list
          frontier num_breadcrumbs
      in
      let root_snarked_ledger =
        Transition_frontier.For_tests.root_snarked_ledger frontier
      in
      don't_wait_for
      @@ Transition_frontier_persistence.listen_to_frontier_broadcast_pipe
           frontier_reader frontier_persistence ;
      let%bind () = store_transitions frontier breadcrumbs in
      let%bind () =
        Transition_frontier_persistence.close_and_finish_copy
          frontier_persistence
      in
      let%bind verifier = Verifier.create ~logger ~pids in
      let%map deserialized_frontier =
        Transition_frontier_persistence.deserialize ~directory_name ~logger
          ~trust_system ~verifier ~root_snarked_ledger
          ~consensus_local_state:
            (Transition_frontier.consensus_local_state frontier)
      in
      Transition_frontier.equal frontier deserialized_frontier

    let%test "Serializing a tree and then deserializing it should give us the \
              same transition_frontier" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Thread_safe.block_on_async_exn
      @@ fun () ->
      let%bind frontier =
        create_root_frontier ~logger ~pids Genesis_ledger.accounts
      in
      test_deserialization max_length frontier

    let%test_unit "Serializing a frontier and then deserializing it  from \
                   genesis should give us the same transition_frontier" =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true ;
      Thread_safe.block_on_async_exn
      @@ fun () ->
      Stubs.with_genesis_frontier ~logger ~pids ~f:(fun frontier ->
          let%map is_serialization_correct =
            test_deserialization (max_length / 2) frontier
          in
          assert is_serialization_correct )

    (* TODO: create a test where a batch of diffs are being applied, but the
       worker dies in the middle. The transition_frontier_database can be left
       in a bad state and it needs a way to recover from it. *)
  end )
