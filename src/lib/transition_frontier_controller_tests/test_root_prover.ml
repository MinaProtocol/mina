open Core
open Async

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

let%test_module "Root_prover" =
  ( module struct
    let to_external_transition breadcrumb =
      Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
      |> With_hash.data |> External_transition.of_verified

    let%test "a node should be able to give a valid proof of their root" =
      let logger = Logger.null () in
      let max_length = 4 in
      (* Generating this many breadcrumbs will ernsure the transition_frontier to be full  *)
      let num_breadcrumbs = max_length + 2 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            create_root_frontier ~logger Genesis_ledger.accounts
          in
          let%bind () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:
                (gen_linear_breadcrumbs ~logger ~size:num_breadcrumbs
                   ~accounts_with_secret_keys:Genesis_ledger.accounts)
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
          let root_with_proof =
            Option.value_exn ~message:"Could not produce an ancestor proof"
              (Root_prover.prove ~logger ~frontier observed_state)
          in
          let%map proof_verified_root, proof_verified_best_tip =
            Root_prover.verify ~logger ~observed_state
              ~peer_root:root_with_proof
            |> Deferred.Or_error.ok_exn
          in
          let open Transition_frontier in
          External_transition.(
            equal
              (of_proof_verified @@ With_hash.data proof_verified_root)
              (to_external_transition @@ root frontier)
            && equal
                 (of_proof_verified @@ With_hash.data proof_verified_best_tip)
                 (to_external_transition @@ best_tip frontier)) )
  end )
