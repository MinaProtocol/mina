open Snark_params
open Tick
open Random_oracle

val signature : Field.t State.t

val signature_for_mainnet : Field.t State.t

val signature_for_testnet : Field.t State.t

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

val snapp_account : Field.t State.t

val snapp_payload : Field.t State.t

val snapp_body : Field.t State.t

val snapp_predicate : Field.t State.t

val snapp_predicate_account : Field.t State.t

val snapp_predicate_protocol_state : Field.t State.t

val party_predicate : Field.t State.t

val party : Field.t State.t

val party_cons : Field.t State.t

val party_node : Field.t State.t

val party_with_protocol_state_predicate : Field.t State.t

val receipt_chain_user_command : Field.t State.t

val receipt_chain_snapp : Field.t State.t

val pending_coinbases : Field.t State.t

val coinbase_stack_data : Field.t State.t

val coinbase_stack_state_hash : Field.t State.t

val coinbase_stack : Field.t State.t

val coinbase : Field.t State.t

val checkpoint_list : Field.t State.t

val merge_snark : Field.t State.t

val base_snark : Field.t State.t

val snapp_uri : Field.t State.t

val snapp_event : Field.t State.t

val snapp_events : Field.t State.t

val snapp_sequence_events : Field.t State.t

val snapp_memo : Field.t State.t

val snapp_test : Field.t State.t
