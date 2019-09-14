open Core
open Coda_base
open Coda_state
open Coda_transition

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  module Merkle_list = Merkle_list_prover.Make (struct
    type value = External_transition.Validated.t

    type context = Transition_frontier.t * int

    type proof_elem = State_body_hash.t

    let to_proof_elem transition =
      transition |> External_transition.Validated.protocol_state
      |> Protocol_state.body |> Protocol_state.Body.hash

    let get_previous ~context:(frontier, global_slot) transition =
      let parent_hash = External_transition.Validated.parent_hash transition in
      let open Option.Let_syntax in
      let%bind parent_breadcrumb =
        Option.merge
          (Transition_frontier.find frontier parent_hash)
          (Transition_frontier.find_in_root_history frontier parent_hash)
          ~f:Fn.const
      in
      let parent_transition =
        Transition_frontier.Breadcrumb.validated_transition parent_breadcrumb
      in
      let parent_global_slot =
        External_transition.Validated.consensus_state parent_transition
        |> Consensus.Data.Consensus_state.global_slot
      in
      if parent_global_slot < global_slot - Consensus.Constants.delta then None
      else Some parent_transition
  end)

  let prove ~frontier ~global_slot state_hash =
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
      Merkle_list.prove ~context:(frontier, global_slot) requested_transition
    in
    (External_transition.Validated.state_hash first_transition, merkle_list)
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
end)
