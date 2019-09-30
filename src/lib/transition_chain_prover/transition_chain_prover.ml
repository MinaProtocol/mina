open Core
open Coda_base
open Coda_transition

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Transition_chain_prover_intf
  with type transition_frontier := Inputs.Transition_frontier.t = struct
  open Inputs

  module Merkle_list = Merkle_list_prover.Make (struct
    type value = External_transition.Validated.t

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

    let to_proof_elem transition =
      transition |> External_transition.Validated.protocol_state_body_hash

    let get_previous ~context transition =
      let parent_hash =
        transition |> External_transition.Validated.parent_hash
      in
      let open Option.Let_syntax in
      let%map breadcrumb =
        Transition_frontier.find_in_frontier_or_root_history context
          parent_hash
      in
      Transition_frontier.Breadcrumb.validated_transition breadcrumb
  end)

  let prove ~frontier state_hash =
    let open Option.Let_syntax in
    let%map requested_breadcrumb =
      Transition_frontier.find_in_frontier_or_root_history frontier state_hash
    in
    let requested_transition =
      Transition_frontier.Breadcrumb.validated_transition requested_breadcrumb
    in
    let first_transition, merkle_list =
      Merkle_list.prove ~context:frontier requested_transition
    in
    (External_transition.Validated.state_hash first_transition, merkle_list)
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
end)
