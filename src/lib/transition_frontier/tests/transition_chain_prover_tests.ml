(* Test for Transition_chain_prover.prove function *)
open Core
open Async

let%test_module "Transition_chain_prover.prove" =
  ( module struct
    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~logger
            ~proof_level:precomputed_values.proof_level
            ~constraint_constants:precomputed_values.constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            () )

    let get_ancestry_proof = Transition_chain_prover.get_ancestry_proof

    let gen_frontier ~max_length chain_size =
      let%map.Quickcheck.Generator frontier, branch =
        Transition_frontier.For_tests.gen_with_branch ~logger ~verifier
          ~precomputed_values ~max_length ~frontier_size:0
          ~branch_size:chain_size ()
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          Deferred.List.iter branch
            ~f:(Transition_frontier.add_breadcrumb_exn frontier) ) ;
      let best_tip = Transition_frontier.best_tip frontier in
      let target_state_hash =
        Transition_frontier.Breadcrumb.state_hash best_tip
      in
      let length b =
        Transition_frontier.Breadcrumb.consensus_state b
        |> Consensus.Data.Consensus_state.blockchain_length
        |> Unsigned.UInt32.to_int
      in
      let root_length = Transition_frontier.root frontier |> length in
      (frontier, target_state_hash, length best_tip - root_length)

    let check_result ~proof_depth ~target_state_hash result =
      let init_state_hash, state_body_hashes = Or_error.ok_exn result in
      if List.length state_body_hashes <> proof_depth then
        failwithf
          "length of state_body_hashes %d is not equal to expected \
           proof_depth: %d"
          (List.length state_body_hashes)
          proof_depth () ;
      if
        Option.is_none
          (Transition_chain_verifier.verify ~target_hash:target_state_hash
             ~transition_chain_proof:(init_state_hash, state_body_hashes) )
      then failwith "Transition_chain_verifier.verify failed"

    let rec kth_ancestor ~frontier hash = function
      | 0 ->
          hash
      | k ->
          let parent_hash =
            Transition_frontier.find frontier hash
            |> Option.value_exn |> Transition_frontier.Breadcrumb.parent_hash
          in
          kth_ancestor ~frontier parent_hash (k - 1)

    let%test_unit "get_ancestry_proof returns valid proof" =
      let proof_depth = 4 in
      let chain_size = proof_depth + 3 in
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:10 chain_size)
        ~f:(fun (frontier, target_state_hash, length_to_root) ->
          get_ancestry_proof frontier ~target_state_hash ~depth:proof_depth
          |> check_result
               ~proof_depth:(Int.min proof_depth length_to_root)
               ~target_state_hash ;
          get_ancestry_proof frontier ~target_state_hash
          |> check_result ~proof_depth:length_to_root ~target_state_hash )

    let%test_unit "get_ancestry_proof can access root history" =
      let max_length = 4 in
      let ancestors_to_drop = 3 in
      Quickcheck.test ~trials:1
        (gen_frontier ~max_length ((max_length * 2) + 3))
        ~f:(fun (frontier, best_tip_hash, length_to_root) ->
          if length_to_root <> max_length then
            failwithf "length_to_root %d should be equal to max_length %d"
              length_to_root max_length () ;
          (* check that root history is more than ancestors_to_drop *)
          let root_history =
            Transition_frontier.(
              Extensions.get_extension (extensions frontier) Root_history)
          in
          if Extensions.Root_history.length root_history < ancestors_to_drop
          then
            failwithf
              "root_history length %d should be more than ancestors_to_drop %d"
              (Extensions.Root_history.length root_history)
              ancestors_to_drop () ;
          let target_state_hash =
            kth_ancestor ~frontier best_tip_hash ancestors_to_drop
          in
          get_ancestry_proof frontier ~target_state_hash
          |> check_result ~proof_depth:max_length ~target_state_hash )

    let%test_unit "get_ancestry_proof handles depth larger than chain correctly"
        =
      let proof_depth = 10 in
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:10 3)
        ~f:(fun (frontier, target_state_hash, length_to_root) ->
          (* Get ancestry proof - should stop when reaching root *)
          get_ancestry_proof frontier ~target_state_hash ~depth:proof_depth
          |> check_result ~proof_depth:length_to_root ~target_state_hash )

    let%test_unit "get_ancestry_proof handles non-best tip correctly" =
      let ancestors_to_drop = 2 in
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:10 10)
        ~f:(fun (frontier, best_tip_hash, length_to_root) ->
          assert (length_to_root - ancestors_to_drop >= 2) ;
          (* Getting great-parent of best tip *)
          let target_state_hash =
            kth_ancestor ~frontier best_tip_hash ancestors_to_drop
          in
          (* Get ancestry proof - should stop when reaching root *)
          get_ancestry_proof frontier ~target_state_hash
            ~depth:(length_to_root - ancestors_to_drop + 1)
          |> check_result
               ~proof_depth:(length_to_root - ancestors_to_drop)
               ~target_state_hash ;
          get_ancestry_proof frontier ~target_state_hash ~depth:2
          |> check_result ~proof_depth:2 ~target_state_hash )

    let%test_unit "get_ancestry_proof rejects negative depth" =
      Quickcheck.test ~trials:1 (gen_frontier ~max_length:5 3)
        ~f:(fun (frontier, target_state_hash, _) ->
          (* Try with negative depth *)
          if
            get_ancestry_proof frontier ~target_state_hash ~depth:(-1)
            |> Or_error.is_ok
          then failwith "get_ancestry_proof should fail" )
  end )
