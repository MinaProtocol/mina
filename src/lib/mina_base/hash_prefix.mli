val signature : Snark_params.Tick.Field.t Random_oracle.State.t

val signature_for_mainnet : Snark_params.Tick.Field.t Random_oracle.State.t

val signature_for_testnet : Snark_params.Tick.Field.t Random_oracle.State.t

val merkle_tree : int -> Snark_params.Tick.Field.t Random_oracle.State.t

val coinbase_merkle_tree :
  int -> Snark_params.Tick.Field.t Random_oracle.State.t

val vrf_message : Snark_params.Tick.Field.t Random_oracle.State.t

val vrf_output : Snark_params.Tick.Field.t Random_oracle.State.t

val vrf_evaluation : Snark_params.Tick.Field.t Random_oracle.State.t

val epoch_seed : Snark_params.Tick.Field.t Random_oracle.State.t

val protocol_state : Snark_params.Tick.Field.t Random_oracle.State.t

val protocol_state_body : Snark_params.Tick.Field.t Random_oracle.State.t

val transition_system_snark : Snark_params.Tick.Field.t Random_oracle.State.t

val account : Snark_params.Tick.Field.t Random_oracle.State.t

val side_loaded_vk : Snark_params.Tick.Field.t Random_oracle.State.t

val snapp_account : Snark_params.Tick.Field.t Random_oracle.State.t

val snapp_payload : Snark_params.Tick.Field.t Random_oracle.State.t

val snapp_body : Snark_params.Tick.Field.t Random_oracle.State.t

val snapp_predicate : Snark_params.Tick.Field.t Random_oracle.State.t

val snapp_predicate_account : Snark_params.Tick.Field.t Random_oracle.State.t

val snapp_predicate_protocol_state :
  Snark_params.Tick.Field.t Random_oracle.State.t

val receipt_chain_user_command : Snark_params.Tick.Field.t Random_oracle.State.t

val receipt_chain_snapp : Snark_params.Tick.Field.t Random_oracle.State.t

val pending_coinbases : Snark_params.Tick.Field.t Random_oracle.State.t

val coinbase_stack_data : Snark_params.Tick.Field.t Random_oracle.State.t

val coinbase_stack_state_hash : Snark_params.Tick.Field.t Random_oracle.State.t

val coinbase_stack : Snark_params.Tick.Field.t Random_oracle.State.t

val coinbase : Snark_params.Tick.Field.t Random_oracle.State.t

val checkpoint_list : Snark_params.Tick.Field.t Random_oracle.State.t

val merge_snark : Snark_params.Tick.Field.t Random_oracle.State.t

val base_snark : Snark_params.Tick.Field.t Random_oracle.State.t
