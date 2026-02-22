open Core
open Mina_base
open Mina_state

module type Inputs_intf = sig
  module Transition_frontier : module type of Transition_frontier
end

module Make (Inputs : Inputs_intf) :
  Mina_intf.Transition_chain_prover_intf
    with type transition_frontier := Inputs.Transition_frontier.t = struct
  open Inputs

  let find_in_root_history frontier state_hash =
    let open Transition_frontier.Extensions in
    let open Option.Let_syntax in
    let root_history =
      get_extension (Transition_frontier.extensions frontier) Root_history
    in
    let%map root_data = Root_history.lookup root_history state_hash in
    let validated_block =
      Frontier_base.Root_data.Historical.transition root_data
    in
    Mina_block.Validated.forget validated_block
    |> With_hash.map
         ~f:(Fn.compose Mina_block.Header.protocol_state Mina_block.header)

  module Merkle_list = Merkle_list_prover.Make_ident (struct
    type value =
      Mina_state.Protocol_state.Value.t State_hash.With_state_hashes.t

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

    let to_proof_elem =
      State_hash.With_state_hashes.state_body_hash
        ~compute_hashes:Mina_state.Protocol_state.hashes

    let get_previous ~context transition =
      let parent_hash =
        With_hash.data transition |> Protocol_state.previous_state_hash
      in
      Option.first_some
        ( Option.map ~f:Frontier_base.Breadcrumb.protocol_state_with_hashes
        @@ Transition_frontier.find context parent_hash )
        (find_in_root_history context parent_hash)
  end)

  let prove ?length ~frontier state_hash =
    let open Option.Let_syntax in
    let%map requested_transition =
      Option.first_some
        ( Option.map ~f:Frontier_base.Breadcrumb.protocol_state_with_hashes
        @@ Transition_frontier.find frontier state_hash )
        (find_in_root_history frontier state_hash)
    in
    let first_transition, merkle_list =
      Merkle_list.prove ?length ~context:frontier requested_transition
    in
    (State_hash.With_state_hashes.state_hash first_transition, merkle_list)
end

include Make (struct
  module Transition_frontier = Transition_frontier
end)
