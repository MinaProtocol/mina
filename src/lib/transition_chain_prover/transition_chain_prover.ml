open Core
open Mina_base
open Mina_state

module type Inputs_intf = sig
  module Transition_frontier : module type of Transition_frontier
end

let parent_hash hh =
  With_hash.data hh |> Mina_block.Header.protocol_state
  |> Protocol_state.previous_state_hash

module Make (Inputs : Inputs_intf) :
  Mina_intf.Transition_chain_prover_intf
    with type transition_frontier := Inputs.Transition_frontier.t = struct
  open Inputs

  let find_in_root_history ~frontier state_hash =
    let open Transition_frontier.Extensions in
    let root_history =
      get_extension (Transition_frontier.extensions frontier) Root_history
    in
    let open Option in
    Root_history.lookup root_history state_hash
    >>| Frontier_base.Root_data.Historical.transition
    >>| Mina_block.Validated.forget
    >>| With_hash.map ~f:Mina_block.header

  let find_in_frontier ~frontier state_hash =
    let open Option in
    Transition_frontier.find frontier state_hash
    >>| Frontier_base.Breadcrumb.block_with_hash
    >>| With_hash.map ~f:Mina_block.header

  let find_in_catchup_state ~frontier state_hash =
    match Transition_frontier.catchup_state frontier with
    | Bit state ->
        Bit_catchup_state.find_header state state_hash
    | _ ->
        None

  let lookup ~frontier state_hash =
    List.find_map
      ~f:(fun f -> f ~frontier state_hash)
      [ find_in_catchup_state; find_in_frontier; find_in_root_history ]

  module Merkle_list = Merkle_list_prover.Make_ident (struct
    type value = Mina_block.Header.with_hash

    type context = Transition_frontier.t

    type proof_elem = State_body_hash.t

    let to_proof_elem =
      State_hash.With_state_hashes.state_body_hash
        ~compute_hashes:
          (Fn.compose Mina_state.Protocol_state.hashes
             Mina_block.Header.protocol_state )

    let get_previous ~context =
      Fn.compose (lookup ~frontier:context) parent_hash
  end)

  let prove ?length ~frontier state_hash =
    let%map.Option requested = lookup ~frontier state_hash in
    let first, merkle_list =
      Merkle_list.prove ?length ~context:frontier requested
    in
    (State_hash.With_state_hashes.state_hash first, merkle_list)

  let prove_with_headers ?length ?(max_headers = 50) ~frontier ~canopy =
    let result_of_acc acc =
      List.hd acc |> Option.map ~f:(fun first -> (parent_hash first, [], acc))
    in
    let rec go rem_headers acc state_hash =
      if State_hash.Set.mem canopy state_hash then Some (state_hash, [], acc)
      else if rem_headers = 0 then
        match prove ?length ~frontier state_hash with
        | None ->
            result_of_acc acc
        | Some (first_hash, body_hashes) ->
            Some (first_hash, body_hashes, acc)
      else
        match lookup ~frontier state_hash with
        | None ->
            result_of_acc acc
        | Some hh ->
            go (rem_headers - 1) (hh :: acc) (parent_hash hh)
    in
    go max_headers []
end

include Make (struct
  module Transition_frontier = Transition_frontier
end)
