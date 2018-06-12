open Nanobit_base.Snark_params

module Step_prover_state = struct
  type t =
    { wrap_vk: Tock.Verification_key.t
    ; prev_proof: Tock.Proof.t
    ; prev_state: Blockchain_snark.Blockchain_state.t
    ; update: Nanobit_base.Block.t }
end

module Wrap_prover_state = struct
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

let keys =
  lazy
    (let module M = struct
       module M = Transition_keys.Make ()

       open M

       let transaction_snark_keys = transaction_snark_keys

       module Step = struct
         include (
           Step :
             module type of Step with module Prover_state := Step.Prover_state )

         module Prover_state = Step_prover_state

         let main x =
           let there {Prover_state.wrap_vk; prev_proof; prev_state; update} =
             {Step.Prover_state.wrap_vk; prev_proof; prev_state; update}
           in
           let back {Step.Prover_state.wrap_vk; prev_proof; prev_state; update} =
             {Prover_state.wrap_vk; prev_proof; prev_state; update}
           in
           let open Tick in
           with_state
             ~and_then:(fun s -> As_prover.set_state (back s))
             As_prover.(map get_state ~f:there)
             (main x)
       end

       module Wrap = struct
         include (
           Wrap :
             module type of Wrap with module Prover_state := Wrap.Prover_state )

         module Prover_state = Wrap_prover_state

         let main x =
           let there {Prover_state.proof} = {Wrap.Prover_state.proof} in
           let back {Wrap.Prover_state.proof} = {Prover_state.proof} in
           let open Tock in
           with_state
             ~and_then:(fun s -> As_prover.set_state (back s))
             As_prover.(map get_state ~f:there)
             (main x)
       end
     end in
    (module M : S))

module Make () = struct
  include (val Lazy.force keys)
end
