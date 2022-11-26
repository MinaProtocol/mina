open Mina_block.Validation
open Core_kernel

(** Container for validation callbacks of gossips.

  Note that each transition may be gossip two times:
  as a header and as a full block (on an old topic which
  is supported until next hardfork).
  *)
type transition_gossip_t =
  | No_validation_callback
  | Gossiped_header of Mina_net2.Validation_callback.t
  | Gossiped_block of Mina_net2.Validation_callback.t
  | Gossiped_both of
      { block_vc : Mina_net2.Validation_callback.t
      ; header_vc : Mina_net2.Validation_callback.t
      }

(** Either a header received through gossip with proof
    verified or a header downloaded as part of catchup
    with proof not yet verified.*)
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

(** Fire validation callbacks contained in the given
    [transition_gossip_t] object *)
let drop_gossip_data validation_result gossip_data =
  match gossip_data with
  | No_validation_callback ->
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
  Option.value ~default:No_validation_callback
  @@ let%bind.Option gt = gossip_type in
     let%map.Option vc = vc_opt in
     match gt with `Header -> Gossiped_header vc | `Block -> Gossiped_block vc

(** Update gossip data kept for a transition to include information
    that became potentially available from a recently received gossip *)
let update_gossip_data ~logger ~state_hash ~vc ~gossip_type old =
  let log_duplicate () =
    [%log warn] "Duplicate %s gossip for $state_hash"
      (match gossip_type with `Block -> "block" | `Header -> "header")
      ~metadata:[ ("state_hash", Mina_base.State_hash.to_yojson state_hash) ]
  in
  match (gossip_type, old) with
  | `Block, Gossiped_header header_vc ->
      Gossiped_both { block_vc = vc; header_vc }
  | `Header, Gossiped_block block_vc ->
      Gossiped_both { block_vc; header_vc = vc }
  | `Block, No_validation_callback ->
      Gossiped_block vc
  | `Header, No_validation_callback ->
      Gossiped_header vc
  | `Header, Gossiped_header _ ->
      log_duplicate () ; old
  | `Header, Gossiped_both _ ->
      log_duplicate () ; old
  | `Block, Gossiped_block _ ->
      log_duplicate () ; old
  | `Block, Gossiped_both _ ->
      log_duplicate () ; old
