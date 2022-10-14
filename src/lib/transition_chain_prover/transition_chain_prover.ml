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
    let root_history =
      get_extension (Transition_frontier.extensions frontier) Root_history
    in
    let%map.Option root_data = Root_history.lookup root_history state_hash in
    Frontier_base.Root_data.Historical.transition root_data

  let lookup ~frontier state_hash =
    let open Transition_frontier in
    Option.merge
      (Option.map ~f:Breadcrumb.validated_transition @@ find frontier state_hash)
      (find_in_root_history frontier state_hash)
      ~f:Fn.const

  module Merkle_list = Merkle_list_prover.Make_ident (struct
    type value = Mina_block.Validated.t

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

    let to_proof_elem = Mina_block.Validated.state_body_hash

    let get_previous ~context transition =
      let parent_hash =
        transition |> Mina_block.Validated.forget |> With_hash.data
        |> Mina_block.header |> Mina_block.Header.protocol_state
        |> Protocol_state.previous_state_hash
      in
      lookup ~frontier:context parent_hash
  end)

  let prove ?length ~frontier state_hash =
    let%map.Option requested_transition = lookup ~frontier state_hash in
    let first_transition, merkle_list =
      Merkle_list.prove ?length ~context:frontier requested_transition
    in
    (Mina_block.Validated.state_hash first_transition, merkle_list)
end

include Make (struct
  module Transition_frontier = Transition_frontier
end)
