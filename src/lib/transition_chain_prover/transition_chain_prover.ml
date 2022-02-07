open Core
open Mina_base

module type Inputs_intf = sig
  module Transition_frontier : module type of Transition_frontier
end

module Make (Inputs : Inputs_intf) :
  Mina_intf.Transition_chain_prover_intf
    with type transition_frontier := Inputs.Transition_frontier.t = struct

  let find_in_root_history frontier state_hash =
    let open Inputs.Transition_frontier.Extensions in
    let open Option.Let_syntax in
    let root_history =
      get_extension (Inputs.Transition_frontier.extensions frontier) Root_history
    in
    let%map root_data = Root_history.lookup root_history state_hash in
    Frontier_base.Root_data.Historical.transition root_data

  module Merkle_list = Merkle_list_prover.Make_ident (struct
    type value = Mina_transition.External_transition.Validated.t

    type context = Inputs.Transition_frontier.t

    type proof_elem = State_body_hash.t

    let to_proof_elem transition =
      transition |> Mina_transition.External_transition.Validated.protocol_state
      |> Mina_state.Protocol_state.body |> Mina_state.Protocol_state.Body.hash

    let get_previous ~context transition =
      let parent_hash =
        transition |> Mina_transition.External_transition.Validated.parent_hash
      in
      let open Option.Let_syntax in
      Option.merge
        Inputs.Transition_frontier.(
          find context parent_hash >>| Breadcrumb.validated_transition)
        (find_in_root_history context parent_hash)
        ~f:Fn.const
  end)

  let prove ?length ~frontier state_hash =
    let open Option.Let_syntax in
    let%map requested_transition =
      Option.merge
        Inputs.Transition_frontier.(
          find frontier state_hash >>| Breadcrumb.validated_transition)
        (find_in_root_history frontier state_hash)
        ~f:Fn.const
    in
    let first_transition, merkle_list =
      Merkle_list.prove ?length ~context:frontier requested_transition
    in
    (Mina_transition.External_transition.Validated.state_hash first_transition, merkle_list)
end

include Make (struct
  module Transition_frontier = Transition_frontier
end)
