open Core
open Coda_base
open Coda_state

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Transition_chain_prover_intf
  with type transition_frontier := Inputs.Transition_frontier.t
   and type external_transition := Inputs.External_transition.t = struct
  open Inputs

  module Merkle_list = Merkle_list_prover.Make (struct
    type value = External_transition.Validated.t

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

    let to_proof_elem transition =
      transition |> External_transition.Validated.protocol_state
      |> Protocol_state.body |> Protocol_state.Body.hash

    let get_previous ~context transition =
      let parent_hash =
        transition |> External_transition.Validated.parent_hash
      in
      let open Option.Let_syntax in
      let%map breadcrumb =
        Option.merge
          (Transition_frontier.find context parent_hash)
          (Transition_frontier.find_in_root_history context parent_hash)
          ~f:Fn.const
      in
      Transition_frontier.Breadcrumb.validated_transition breadcrumb
  end)

  let prove ?length ~frontier state_hash =
    let open Option.Let_syntax in
    let%map requested_breadcrumb =
      Option.merge
        (Transition_frontier.find frontier state_hash)
        (Transition_frontier.find_in_root_history frontier state_hash)
        ~f:Fn.const
    in
    let requested_transition =
      Transition_frontier.Breadcrumb.validated_transition requested_breadcrumb
    in
    let first_transition, merkle_list =
      Merkle_list.prove ?length ~context:frontier requested_transition
    in
    (External_transition.Validated.state_hash first_transition, merkle_list)
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
end)
