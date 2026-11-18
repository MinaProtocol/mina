open Async
open Core

let%test_module "Closing the frontier" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default
            ~constraint_constants:precomputed_values.constraint_constants
            ~logger ~proof_level:precomputed_values.proof_level () )

    let gen_frontier_and_chain =
      Transition_frontier.For_tests.gen_with_branch ~precomputed_values
        ~verifier ~max_length:2 ~frontier_size:1 ~branch_size:4 ()

    let%test_unit "Closing a frontier twice closes it once" =
      Quickcheck.test ~trials:1 gen_frontier_and_chain
        ~f:(fun (frontier, _chain) ->
          Thread_safe.block_on_async_exn (fun () ->
              let first = Transition_frontier.close ~loc:__LOC__ frontier in
              let second = Transition_frontier.close ~loc:__LOC__ frontier in
              let%map () = Deferred.both first second |> Deferred.ignore_m in
              assert (
                Deferred.is_determined (Transition_frontier.closed frontier) ) ) )
  end )
