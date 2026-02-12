(** Generic (polymorphic instance of [challenge_polynomial]) *)
val challenge_polynomial :
     (module Vinegar_types.Shifted_value.Field_intf with type t = 'a)
  -> 'a array
  -> ('a -> 'a) Core_kernel.Staged.t

type ('a, 'a_opt) index' =
  ('a, 'a_opt) Vinegar_types.Plonk_verification_key_evals.Step.t

module Challenge : module type of Import.Challenge.Make (Impls.Wrap)

module Digest : module type of Import.Digest.Make (Impls.Wrap)

module Scalar_challenge :
    module type of
      Scalar_challenge.Make
        (Wrap_main_inputs.Impl)
        (Wrap_main_inputs.Inner_curve)
        (Challenge)
        (Endo.Wrap_inner_curve)

module Other_field : sig
  module Packed : sig
    type t = Impls.Wrap.Other_field.t

    val typ :
      (Impls.Wrap.Impl.Field.t, Backend.Tick.Field.t) Impls.Wrap_impl.Typ.t
  end
end

module Vinegar_one_hot_vector : module type of Vinegar_one_hot_vector.Make (Impls.Wrap)

module Vinegar_pseudo : module type of Vinegar_pseudo.Make (Impls.Wrap)

module Opt : sig
  include module type of
      Opt_sponge.Make (Impls.Wrap) (Wrap_main_inputs.Sponge.Permutation)
end

val all_possible_domains :
  ( unit
  , ( Vinegar_base.Domain.Stable.V1.t
    , Wrap_hack.Padded_length.n Vinegar_types.Nat.s )
    Vinegar_types.Vector.t )
  Core_kernel.Memo.fn

val num_possible_domains :
  Wrap_hack.Padded_length.n Vinegar_types.Nat.s Vinegar_types.Nat.t

val assert_n_bits :
  n:int -> Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t -> unit

val incrementally_verify_proof :
     (module Vinegar_types.Nat.Add.Intf with type n = 'b)
  -> actual_proofs_verified_mask:
       ( Wrap_main_inputs.Impl.Field.t Snarky_backendless.Boolean.t
       , 'b )
       Vinegar_types.Vector.t
  -> step_domains:(Import.Domains.t, 'a) Vinegar_types.Vector.t
  -> srs:Kimchi_bindings.Protocol.SRS.Fp.t
  -> verification_key:
       ( Wrap_main_inputs.Inner_curve.t array
       , ( Wrap_main_inputs.Inner_curve.t array
         , Impls.Wrap.Boolean.var )
         Vinegar_types.Opt.t )
       Vinegar_types.Plonk_verification_key_evals.Step.t
  -> xi:Scalar_challenge.t
  -> sponge:Opt.t
  -> public_input:
       [ `Field of
         Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Boolean.var
       | `Packed_bits of Wrap_main_inputs.Impl.Field.t * int ]
       array
  -> sg_old:
       ( Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Field.t
       , 'b )
       Vinegar_types.Vector.t
  -> advice:
       Other_field.Packed.t Vinegar_types.Shifted_value.Type1.t
       Import.Types.Step.Bulletproof.Advice.t
  -> messages:
       ( Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Field.t
       , Wrap_main_inputs.Impl.Boolean.var )
       Vinegar_types.Plonk_types.Messages.In_circuit.t
  -> which_branch:'a Vinegar_one_hot_vector.t
  -> openings_proof:
       ( Wrap_main_inputs.Inner_curve.t
       , Other_field.Packed.t Vinegar_types.Shifted_value.Type1.t )
       Vinegar_types.Plonk_types.Openings.Bulletproof.t
  -> plonk:
       ( Wrap_main_inputs.Impl.Field.t
       , Wrap_main_inputs.Impl.Field.t Import.Scalar_challenge.t
       , Wrap_main_inputs.Impl.Field.t Vinegar_types.Shifted_value.Type1.t
       , ( Wrap_main_inputs.Impl.Field.t Vinegar_types.Shifted_value.Type1.t
         , Wrap_main_inputs.Impl.Boolean.var )
         Vinegar_types.Opt.t
       , ( Wrap_main_inputs.Impl.Field.t Import.Scalar_challenge.t
         , Wrap_main_inputs.Impl.Boolean.var )
         Vinegar_types.Opt.t
       , Wrap_main_inputs.Impl.Boolean.var )
       Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
  -> Wrap_main_inputs.Impl.Field.t
     * ( [> `Success of Wrap_main_inputs.Impl.Boolean.var ]
       * Scalar_challenge.t Import.Bulletproof_challenge.t Core_kernel.Array.t
       )

val finalize_other_proof :
     (module Vinegar_types.Nat.Add.Intf with type n = 'b)
  -> domain:
       < generator : Wrap_main_inputs.Impl.Field.t
       ; shifts : Wrap_main_inputs.Impl.Field.t array
       ; vanishing_polynomial :
              Wrap_main_inputs.Impl.field Snarky_backendless__.Cvar.t
           -> Wrap_main_inputs.Impl.field Snarky_backendless__.Cvar.t
       ; .. >
  -> sponge:Wrap_main_inputs.Sponge.t
  -> old_bulletproof_challenges:
       ( (Wrap_main_inputs.Impl.Field.t, 'a) Vinegar_types.Vector.t
       , 'b )
       Vinegar_types.Vector.t
  -> ( Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
     , Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
       Import.Scalar_challenge.t
     , Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
       Vinegar_types.Shifted_value.Type2.t
     , ( Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
         Import.Scalar_challenge.t
         Import.Bulletproof_challenge.t
       , 'c )
       Vinegar_types.Vector.t )
     Import.Types.Step.Proof_state.Deferred_values.In_circuit.t
  -> ( Wrap_main_inputs.Impl.Field.t
     , Wrap_main_inputs.Impl.Field.t Array.t
     , Wrap_main_inputs.Impl.Boolean.var )
     Vinegar_types.Plonk_types.All_evals.In_circuit.t
  -> Wrap_main_inputs.Impl.Boolean.var
     * ( Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
       , 'c )
       Vinegar_types.Vector.t

val choose_key :
  'n.
     'n Vinegar_one_hot_vector.t
  -> ( ( Wrap_main_inputs.Inner_curve.t array
       , ( Wrap_main_inputs.Inner_curve.t array
         , Impls.Wrap.Boolean.var )
         Vinegar_types.Opt.t )
       index'
     , 'n )
     Vinegar_types.Vector.t
  -> ( Wrap_main_inputs.Inner_curve.t array
     , ( Wrap_main_inputs.Inner_curve.t array
       , Impls.Wrap.Boolean.var )
       Vinegar_types.Opt.t )
     index'
