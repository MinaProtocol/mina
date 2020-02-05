[%%import "/src/config.mlh"]

[%%ifdef consensus_mechanism]

open Snark_params
open Tick

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

open Random_oracle

val signature : Field.t State.t

val merkle_tree : Field.t State.t array

val coinbase_merkle_tree : Field.t State.t array

val vrf_message : Field.t State.t

val vrf_output : Field.t State.t

val epoch_seed : Field.t State.t

val protocol_state : Field.t State.t

val protocol_state_body : Field.t State.t

val transition_system_snark : Field.t State.t

val account : Field.t State.t

val receipt_chain : Field.t State.t

val pending_coinbases : Field.t State.t

val coinbase_stack_data : Field.t State.t

val coinbase_stack_state_hash : Field.t State.t

val coinbase_stack : Field.t State.t

val coinbase : Field.t State.t

val checkpoint_list : Field.t State.t

val merge_snark : Field.t State.t

val base_snark : Field.t State.t
