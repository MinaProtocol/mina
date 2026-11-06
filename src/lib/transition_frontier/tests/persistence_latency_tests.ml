open Core
open Async

let%test_module "Persisting the frontier" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default
            ~constraint_constants:precomputed_values.constraint_constants
            ~logger ~proof_level:precomputed_values.proof_level () )

    (* Five block windows, the most a diff waits to be persisted. *)
    let max_latency =
      Time.Span.of_ms
        ( 5.
        *. Float.of_int
             precomputed_values.constraint_constants.block_window_duration_ms )

    let persisted_best_tip frontier =
      let persistent_frontier =
        Transition_frontier.persistent_frontier frontier
      in
      let instance =
        Option.value_exn
          persistent_frontier
            .Transition_frontier.Persistent_frontier.Factory_type.instance
      in
      Transition_frontier.Persistent_frontier.Database.get_best_tip
        instance.Transition_frontier.Persistent_frontier.Instance_type.db
      |> Result.ok

    let%test_unit "Diffs fewer than a flush are persisted within the maximum \
                   latency" =
      (* Few enough blocks that their diffs don't fill a flush. *)
      let frontier =
        Quickcheck.random_value
          (Transition_frontier.For_tests.gen ~logger ~precomputed_values
             ~verifier ~max_length:10 ~size:3 () )
      in
      let best_tip =
        Transition_frontier.(Breadcrumb.state_hash (best_tip frontier))
      in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind () = after (Time.Span.( + ) max_latency (sec 2.)) in
          [%test_eq: Mina_base.State_hash.t option]
            (persisted_best_tip frontier)
            (Some best_tip) ;
          Transition_frontier.close ~loc:__LOC__ frontier )
  end )
