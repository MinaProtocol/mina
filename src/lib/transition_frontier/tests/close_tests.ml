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

let%test_module "Adding to a closing frontier" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default
            ~constraint_constants:precomputed_values.constraint_constants
            ~logger ~proof_level:precomputed_values.proof_level () )

    (* A frontier that is full, so that the next block moves its root. *)
    let gen_frontier_and_chain =
      Transition_frontier.For_tests.gen_with_branch ~precomputed_values
        ~verifier ~max_length:2 ~frontier_size:2 ~branch_size:1 ()

    let%test_unit "An add to a closing frontier fails without changing it" =
      Quickcheck.test ~trials:1 gen_frontier_and_chain
        ~f:(fun (frontier, chain) ->
          Thread_safe.block_on_async_exn (fun () ->
              let root =
                Transition_frontier.(Breadcrumb.state_hash (root frontier))
              in
              let closed = Transition_frontier.close ~loc:__LOC__ frontier in
              let%bind added =
                Monitor.try_with ~here:[%here] (fun () ->
                    Transition_frontier.add_breadcrumb_exn frontier
                      (List.hd_exn chain) )
              in
              ( match added with
              | Ok () ->
                  failwith "the add succeeded"
              | Error exn ->
                  (* Refused by the closing check, not failing somewhere
                     inside the add. *)
                  assert (
                    String.is_substring (Exn.to_string exn)
                      ~substring:"to a frontier that is closing" ) ) ;
              [%test_eq: Mina_base.State_hash.t]
                Transition_frontier.(Breadcrumb.state_hash (root frontier))
                root ;
              closed ) )
  end )
