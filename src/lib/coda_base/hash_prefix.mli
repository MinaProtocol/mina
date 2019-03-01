open Snark_params

val length_in_triples : int

val protocol_state : Tick.Pedersen.State.t

val protocol_state_body : Tick.Pedersen.State.t

val signature : Tick.Pedersen.State.t

val account : Tick.Pedersen.State.t

val merkle_tree : Tick.Pedersen.State.t array

val coinbase_merkle_tree : Tick.Pedersen.State.t array

val proof_of_work : Tick.Pedersen.State.t

val merge_snark : Tick.Pedersen.State.t

val base_snark : Tick.Pedersen.State.t

val transition_system_snark : Tick.Pedersen.State.t

val receipt_chain : Tick.Pedersen.State.t

val epoch_seed : Tick.Pedersen.State.t

val vrf_message : Tick.Pedersen.State.t

val vrf_output : Tick.Pedersen.State.t

val pending_coinbases : Tick.Pedersen.State.t

val coinbase_stack : Tick.Pedersen.State.t

val coinbase : Tick.Pedersen.State.t
