open Nanobit_base.Snark_params

module Step_prover_state : sig
  type t =
    { wrap_vk: Tock.Verification_key.t
    ; prev_proof: Tock.Proof.t
    ; prev_state: Blockchain_snark.Blockchain_state.t
    ; update: Nanobit_base.Block.t }
end

module Wrap_prover_state : sig
  type t = {proof: Tick.Proof.t}
end

module type S = sig
  val transaction_snark_keys : Transaction_snark.Keys.t

  module Step : sig
    val verification_key : Tick.Verification_key.t

    val proving_key : Tick.Proving_key.t

    val input :
         unit
      -> ('a, 'b, Tick.Field.var -> 'a, Tick.Field.t -> 'b) Tick.Data_spec.t

    module Verifier : sig
      module Verification_key : sig
        val to_bool_list : Tock.Verification_key.t -> bool list
      end
    end

    module Prover_state = Step_prover_state

    val main : Tick.Field.var -> (unit, Prover_state.t) Tick.Checked.t
  end

  module Wrap : sig
    val verification_key : Tock.Verification_key.t

    val proving_key : Tock.Proving_key.t

    val input :
         unit
      -> ('a, 'b, Tock.Field.var -> 'a, Tock.Field.t -> 'b) Tock.Data_spec.t

    module Prover_state = Wrap_prover_state

    val main : Tock.Field.var -> (unit, Prover_state.t) Tock.Checked.t
  end
end

module Make () : S
