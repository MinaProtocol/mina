(** Generic (polymorphic instance of [challenge_polynomial]) *)
val challenge_polynomial :
     (module Pickles_types.Shifted_value.Field_intf with type t = 'a)
  -> 'a array
  -> ('a -> 'a) Core_kernel.Staged.t

type ('a, 'a_opt) index' =
  ('a, 'a_opt) Pickles_types.Plonk_verification_key_evals.Step.t

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
      ( Impls.Wrap.Impl.Field.t
      , Backend.Tick.Field.t
      , Impls.Wrap_impl.Internal_Basic.Field.t )
      Snarky_backendless.Typ.t
  end
end

module One_hot_vector : module type of One_hot_vector.Make (Impls.Wrap)

module Pseudo : module type of Pseudo.Make (Impls.Wrap)

module Opt : sig
  include module type of
      Opt_sponge.Make (Impls.Wrap) (Wrap_main_inputs.Sponge.Permutation)
end

val all_possible_domains :
  ( unit
  , ( Pickles_base.Domain.Stable.V1.t
    , Wrap_hack.Padded_length.n Pickles_types.Nat.s )
    Pickles_types.Vector.t )
  Core_kernel.Memo.fn

val num_possible_domains :
  Wrap_hack.Padded_length.n Pickles_types.Nat.s Pickles_types.Nat.t

val assert_n_bits :
  n:int -> Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t -> unit

val incrementally_verify_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> actual_proofs_verified_mask:
       ( Wrap_main_inputs.Impl.Field.t Snarky_backendless.Boolean.t
       , 'b )
       Pickles_types.Vector.t
  -> step_domains:(Import.Domains.t, 'a) Pickles_types.Vector.t
  -> srs:Kimchi_bindings.Protocol.SRS.Fp.t
  -> verification_key:
       ( Wrap_main_inputs.Inner_curve.t
       , ( Wrap_main_inputs.Inner_curve.t
         , Impls.Wrap.Boolean.var )
         Pickles_types.Opt.t )
       Pickles_types.Plonk_verification_key_evals.Step.t
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
       Pickles_types.Vector.t
  -> advice:
       Other_field.Packed.t Pickles_types.Shifted_value.Type1.t
       Import.Types.Step.Bulletproof.Advice.t
  -> messages:
       ( Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Field.t
       , Wrap_main_inputs.Impl.Boolean.var )
       Pickles_types.Plonk_types.Messages.In_circuit.t
  -> which_branch:'a One_hot_vector.t
  -> openings_proof:
       ( Wrap_main_inputs.Inner_curve.t
       , Other_field.Packed.t Pickles_types.Shifted_value.Type1.t )
       Pickles_types.Plonk_types.Openings.Bulletproof.t
  -> plonk:
       ( Wrap_main_inputs.Impl.Field.t
       , Wrap_main_inputs.Impl.Field.t Import.Scalar_challenge.t
       , Wrap_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
       , ( Wrap_main_inputs.Impl.Field.t Import.Scalar_challenge.t
         , Wrap_main_inputs.Impl.Boolean.var )
         Pickles_types.Opt.t
       , Wrap_main_inputs.Impl.Boolean.var )
       Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
  -> Wrap_main_inputs.Impl.Field.t
     * ( [> `Success of Wrap_main_inputs.Impl.Boolean.var ]
       * Scalar_challenge.t Import.Bulletproof_challenge.t Core_kernel.Array.t
       )

val finalize_other_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> domain:
       < generator : Wrap_main_inputs.Impl.Field.t
       ; shifts : Wrap_main_inputs.Impl.Field.t array
       ; vanishing_polynomial :
              Wrap_main_inputs.Impl.field Snarky_backendless__.Cvar.t
           -> Wrap_main_inputs.Impl.field Snarky_backendless__.Cvar.t
       ; .. >
  -> sponge:Wrap_main_inputs.Sponge.t
  -> old_bulletproof_challenges:
       ( (Wrap_main_inputs.Impl.Field.t, 'a) Pickles_types.Vector.t
       , 'b )
       Pickles_types.Vector.t
  -> ( Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
     , Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
       Import.Scalar_challenge.t
     , Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
       Pickles_types.Shifted_value.Type2.t
     , ( Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
         Import.Scalar_challenge.t
         Import.Bulletproof_challenge.t
       , 'c )
       Pickles_types.Vector.t )
     Import.Types.Step.Proof_state.Deferred_values.In_circuit.t
  -> ( Wrap_main_inputs.Impl.Field.t
     , Wrap_main_inputs.Impl.Field.t Array.t
     , Wrap_main_inputs.Impl.Boolean.var )
     Pickles_types.Plonk_types.All_evals.In_circuit.t
  -> Wrap_main_inputs.Impl.Boolean.var
     * ( Wrap_main_inputs.Impl.field Snarky_backendless.Cvar.t
       , 'c )
       Pickles_types.Vector.t

val choose_key :
  'n.
     'n One_hot_vector.t
  -> ( ( Wrap_main_inputs.Inner_curve.t
       , ( Wrap_main_inputs.Inner_curve.t
         , Impls.Wrap.Boolean.var )
         Pickles_types.Opt.t )
       index'
     , 'n )
     Pickles_types.Vector.t
  -> ( Wrap_main_inputs.Inner_curve.t
     , ( Wrap_main_inputs.Inner_curve.t
       , Impls.Wrap.Boolean.var )
       Pickles_types.Opt.t )
     index'
