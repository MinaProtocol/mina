open Snark_params
open Step
open Random_oracle

val signature : Field.t State.t

val signature_for_mainnet : Field.t State.t

val signature_for_testnet : Field.t State.t

val signature_legacy : Field.t Legacy.State.t

val signature_for_mainnet_legacy : Field.t Legacy.State.t

val signature_for_testnet_legacy : Field.t Legacy.State.t

(** [merkle_tree depth] gives the hash prefix for the given node depth.

    This function performs caching: all prefixes up to the given depth will be
    computed, and subsequent calls will retrieve them with negligible cost.
*)
val merkle_tree : int -> Field.t State.t

val coinbase_merkle_tree : int -> Field.t State.t

val vrf_message : Field.t State.t

val vrf_output : Field.t State.t

val vrf_evaluation : Field.t State.t

val epoch_seed : Field.t State.t

val protocol_state : Field.t State.t

val protocol_state_body : Field.t State.t

val transition_system_snark : Field.t State.t

val account : Field.t State.t

val side_loaded_vk : Field.t State.t

val zkapp_account : Field.t State.t

val zkapp_payload : Field.t State.t

val zkapp_body : Field.t State.t

val zkapp_precondition : Field.t State.t

val zkapp_precondition_account : Field.t State.t

val zkapp_precondition_protocol_state : Field.t State.t

val account_update_account_precondition : Field.t State.t

val account_update : Field.t State.t

val account_update_cons : Field.t State.t

val account_update_node : Field.t State.t

val account_update_stack_frame : Field.t State.t

val account_update_stack_frame_cons : Field.t State.t

val receipt_chain_signed_command : Field.t Legacy.State.t

val receipt_chain_zkapp_command : Field.t State.t

val receipt_chain_zkapp : Field.t State.t

val pending_coinbases : Field.t State.t

val coinbase_stack_data : Field.t State.t

val coinbase_stack_state_hash : Field.t State.t

val coinbase_stack : Field.t State.t

val coinbase : Field.t State.t

val checkpoint_list : Field.t State.t

val merge_snark : Field.t State.t

val base_snark : Field.t State.t

val zkapp_uri : Field.t State.t

val zkapp_event : Field.t State.t

val zkapp_events : Field.t State.t

val zkapp_sequence_events : Field.t State.t

val zkapp_memo : Field.t State.t

val zkapp_test : Field.t State.t

val derive_token_id : Field.t State.t
