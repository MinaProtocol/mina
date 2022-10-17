open Mina_block.Validation
open Core_kernel

type transition_gossip_t =
  | Not_a_gossip
  | Gossiped_header of Mina_net2.Validation_callback.t
  | Gossiped_block of Mina_net2.Validation_callback.t
  | Gossiped_both of
      { block_vc : Mina_net2.Validation_callback.t
      ; header_vc : Mina_net2.Validation_callback.t
      }

type received_header =
  | Pre_initial_valid of pre_initial_valid_with_header
  | Initial_valid of initial_valid_with_header

let pre_initial_valid_of_received_header = function
  | Pre_initial_valid h ->
      h
  | Initial_valid h ->
      Mina_block.Validation.reset_proof_validation_header h

let header_with_hash_of_received_header = function
  | Pre_initial_valid h ->
      Mina_block.Validation.header_with_hash h
  | Initial_valid h ->
      Mina_block.Validation.header_with_hash h

let state_hash_of_received_header =
  Fn.compose Mina_base.State_hash.With_state_hashes.state_hash
    header_with_hash_of_received_header

let drop_gossip_data validation_result gossip_data =
  match gossip_data with
  | Not_a_gossip ->
      ()
  | Gossiped_header vc ->
      Mina_net2.Validation_callback.fire_if_not_already_fired vc
        validation_result
  | Gossiped_block vc ->
      Mina_net2.Validation_callback.fire_if_not_already_fired vc
        validation_result
  | Gossiped_both { block_vc; header_vc } ->
      Mina_net2.Validation_callback.fire_if_not_already_fired block_vc
        validation_result ;
      Mina_net2.Validation_callback.fire_if_not_already_fired header_vc
        validation_result

let create_gossip_data ?gossip_type vc_opt =
  Option.value ~default:Not_a_gossip
  @@ let%bind.Option gt = gossip_type in
     let%map.Option vc = vc_opt in
     match gt with `Header -> Gossiped_header vc | `Block -> Gossiped_block vc
