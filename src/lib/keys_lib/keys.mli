open Snark_params

module type S = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  module Step_prover_state : sig
    type t =
      { wrap_vk: Tock.Verification_key.t
      ; prev_proof: Tock.Proof.t
      ; prev_state: Consensus_mechanism.Protocol_state.value
      ; update: Consensus_mechanism.Snark_transition.value }
  end

  module Wrap_prover_state : sig
    type t = {proof: Tick.Groth16.Proof.t}
  end

  val transaction_snark_keys : Transaction_snark.Keys.Verification.t

  module Step : sig
    val keys : Tick.Groth16.Keypair.t

    val input :
         unit
      -> ( 'a
         , 'b
         , Tick.Field.var -> 'a
         , Tick.Field.t -> 'b )
         Tick.Groth16.Data_spec.t

    module Verification_key : sig
      val to_bool_list : Tock.Verification_key.t -> bool list
    end

    module Prover_state = Step_prover_state

    val instance_hash :
      Consensus_mechanism.Protocol_state.value -> Tick.Field.t

    val main : Tick.Field.var -> (unit, Prover_state.t) Tick.Checked.t
  end

  module Wrap : sig
    val keys : Tock.Keypair.t

    val input :
      ('a, 'b, Wrap_input.var -> 'a, Wrap_input.t -> 'b) Tock.Data_spec.t

    module Prover_state = Wrap_prover_state

    val main : Wrap_input.var -> (unit, Prover_state.t) Tock.Checked.t
  end
end

module Make (Consensus_mechanism : Consensus.Mechanism.S) : sig
  module type S = S with module Consensus_mechanism = Consensus_mechanism

  val create : unit -> (module S) Async.Deferred.t
end
