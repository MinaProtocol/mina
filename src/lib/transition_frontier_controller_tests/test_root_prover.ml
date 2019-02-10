open Core
open Async
open Stubs

let%test_module "Root_prover" =
  ( module struct
    let to_external_transition breadcrumb =
      Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
      |> With_hash.data |> External_transition.of_verified

    let%test "a node should be able to give a valid proof of their root" =
      let logger = Logger.create () in
      let max_length = 4 in
      (* Generating this many breadcrumbs will ernsure the transition_frontier to be full  *)
      let num_breadcrumbs = max_length + 2 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~max_length ~logger in
          let%bind () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
                Quickcheck.Generator.with_size ~size:num_breadcrumbs
                @@ Quickcheck_lib.gen_imperative_list
                     (root_breadcrumb |> return |> Quickcheck.Generator.return)
                     (gen_breadcrumb ~logger) )
          in
          let seen_transition =
            Transition_frontier.(
              all_breadcrumbs frontier |> List.permute |> List.hd_exn
              |> Breadcrumb.transition_with_hash |> With_hash.data)
          in
          let observed_state =
            External_transition.Verified.protocol_state seen_transition
            |> Consensus.Protocol_state.consensus_state
          in
          let root_prover =
            Root_prover.create ~logger ~finality_length:max_length
          in
          let root_with_proof =
            Option.value_exn ~message:"Could not produce an ancestor proof"
              (Root_prover.prove ~frontier root_prover observed_state)
          in
          (let open Deferred.Or_error.Let_syntax in
          let%map proof_verified_root, proof_verified_best_tip =
            Root_prover.verify root_prover ~observed_state
              ~peer_root:root_with_proof
          in
          let open Transition_frontier in
          External_transition.(
            equal
              (of_proof_verified proof_verified_root)
              (to_external_transition @@ root frontier)
            && equal
                 (of_proof_verified proof_verified_best_tip)
                 (to_external_transition @@ best_tip frontier)))
          |> Deferred.Or_error.ok_exn )
  end )
