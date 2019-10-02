open Snark_params

module Random_oracle : sig
  open Tick
  open Random_oracle

  val signature : Field.t State.t

  val merkle_tree : Field.t State.t array

  val coinbase_merkle_tree : Field.t State.t array

  val vrf_message : Field.t State.t

  val vrf_output : Field.t State.t

  val epoch_seed : Field.t State.t

  val protocol_state : Field.t State.t

  val protocol_state_body : Field.t State.t
end

val length_in_triples : int

val account : Tick.Pedersen.State.t

val proof_of_work : Tick.Pedersen.State.t

val merge_snark : Tick.Pedersen.State.t

val base_snark : Tick.Pedersen.State.t

val transition_system_snark : Tick.Pedersen.State.t

val receipt_chain : Tick.Pedersen.State.t

val pending_coinbases : Tick.Pedersen.State.t

val coinbase_stack_data : Tick.Pedersen.State.t

val coinbase_stack_state_hash : Tick.Pedersen.State.t

val coinbase_stack : Tick.Pedersen.State.t

val coinbase : Tick.Pedersen.State.t

val checkpoint_list : Tick.Pedersen.State.t
