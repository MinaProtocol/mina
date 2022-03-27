val length_in_bytes : int

module T : sig
  type t = private string

  val create : string -> t
end

type t = T.t

val create : string -> t

val protocol_state : t

val protocol_state_body : t

val account : t

val side_loaded_vk : t

val snapp_account : t

val snapp_payload : t

val snapp_body : t

val merkle_tree : int -> t

val coinbase_merkle_tree : int -> t

val merge_snark : t

val base_snark : t

val transition_system_snark : t

val signature_testnet : t

val signature_mainnet : t

val receipt_chain_user_command : t

val receipt_chain_snapp : t

val epoch_seed : t

val vrf_message : t

val vrf_output : t

val vrf_evaluation : t

val pending_coinbases : t

val coinbase_stack_data : t

val coinbase_stack_state_hash : t

val coinbase_stack : t

val coinbase : t

val checkpoint_list : t

val bowe_gabizon_hash : t

val snapp_predicate : t

val snapp_predicate_account : t

val snapp_predicate_protocol_state : t
