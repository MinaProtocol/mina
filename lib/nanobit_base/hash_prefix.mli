open Snark_params

val length_in_bits : int

val blockchain_state : Tick.Pedersen.State.t

val signature : Tick.Pedersen.State.t

val account : Tick.Pedersen.State.t

val merkle_tree : Tick.Pedersen.State.t array

val proof_of_work : Tick.Pedersen.State.t

val merge_snark : Tick.Pedersen.State.t

val base_snark : Tick.Pedersen.State.t

val transition_system_snark : Tick.Pedersen.State.t
