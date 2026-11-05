open Async
open Core
open Mina_base

let%test_module "Reporting root transitions" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default
            ~constraint_constants:precomputed_values.constraint_constants
            ~logger ~proof_level:precomputed_values.proof_level () )

    (* A frontier holding at most two blocks above its root, holding just its
       root, and a chain of four blocks on that root. *)
    let gen_frontier_and_chain =
      Transition_frontier.For_tests.gen_with_branch ~precomputed_values
        ~verifier ~max_length:2 ~frontier_size:1 ~branch_size:4 ()

    let state_hash = Transition_frontier.Breadcrumb.state_hash

    let%test_unit "Adding a block reports the root transition it applied" =
      Quickcheck.test ~trials:1 gen_frontier_and_chain
        ~f:(fun (frontier, chain) ->
          Thread_safe.block_on_async_exn (fun () ->
              Deferred.List.iteri chain ~f:(fun i breadcrumb ->
                  let previous_root =
                    state_hash (Transition_frontier.root frontier)
                  in
                  let%map report =
                    Transition_frontier.add_breadcrumb_reporting_root_exn
                      frontier breadcrumb
                  in
                  let root = state_hash (Transition_frontier.root frontier) in
                  match report with
                  | None ->
                      (* The first two blocks fit above the root. *)
                      assert (i < 2) ;
                      [%test_eq: State_hash.t] root previous_root
                  | Some report ->
                      assert (i >= 2) ;
                      [%test_eq: State_hash.t] report.previous_root
                        previous_root ;
                      [%test_eq: State_hash.t] report.new_root root ;
                      List.iter (report.previous_root :: report.garbage)
                        ~f:(fun hash ->
                          assert (
                            Option.is_none
                              (Transition_frontier.find frontier hash) ) ) ) ) )
  end )
