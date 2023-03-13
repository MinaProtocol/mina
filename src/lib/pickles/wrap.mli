open Pickles_types

val wrap :
     max_proofs_verified:'max_proofs_verified Pickles_types.Nat.t
  -> (module Pickles_types.Hlist.Maxes.S
        with type length = 'max_proofs_verified
         and type ns = 'max_local_max_proofs_verifieds )
  -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
  -> dlog_plonk_index:
       Backend.Tock.Curve.Affine.t Pickles_types.Plonk_verification_key_evals.t
  -> (   ( Impls.Wrap.Impl.Field.t
         , Impls.Wrap.Impl.Field.t Composition_types.Scalar_challenge.t
         , Impls.Wrap.Impl.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Impls.Wrap.Impl.Field.t Pickles_types.Shifted_value.Type1.t
           , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Plonk_types.Opt.t
         , ( Impls.Wrap.Impl.Field.t Composition_types.Scalar_challenge.t
             Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
             .Lookup
             .t
           , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Plonk_types.Opt.t
         , Impls.Wrap.Impl.Boolean.var
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
         , ( Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
             Kimchi_backend_common.Scalar_challenge.t
             Composition_types.Bulletproof_challenge.t
           , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
           Pickles_types.Vector.t
           Pickles_types.Hlist0.Id.t
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t )
         Import.Types.Wrap.Statement.In_circuit.t
      -> unit )
  -> typ:('a, 'b) Impls.Step.Typ.t
  -> step_vk:Kimchi_bindings.Protocol.VerifierIndex.Fp.t
  -> actual_wrap_domains:(Core_kernel.Int.t, 'c) Pickles_types.Vector.t
  -> step_plonk_indices:'d
  -> feature_flags:Plonk_types.Opt.Flag.t Plonk_types.Features.t
  -> actual_feature_flags:bool Plonk_types.Features.t
  -> ?tweak_statement:
       (   ( Import.Challenge.Constant.t
           , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
           , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
             , bool )
             Import.Types.Opt.t
           , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
               Composition_types.Wrap.Proof_state.Deferred_values.Plonk
               .In_circuit
               .Lookup
               .t
             , bool )
             Import.Types.Opt.t
           , bool
           , 'max_proofs_verified
             Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
           , (int64, Composition_types.Digest.Limbs.n) Pickles_types.Vector.vec
           , ( 'b
             , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.Stable.V1.t
               , 'actual_proofs_verified )
               Pickles_types.Vector.t
             , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                   Import.Bulletproof_challenge.t
                 , 'e )
                 Pickles_types.Vector.t
               , 'actual_proofs_verified )
               Pickles_types.Vector.t )
             Proof.Base.Messages_for_next_proof_over_same_field.Step.t
           , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
             Import.Types.Bulletproof_challenge.t
             Import.Types.Step_bp_vec.t
           , Import.Types.Branch_data.t )
           Import.Types.Wrap.Statement.In_circuit.t
        -> ( Import.Challenge.Constant.t
           , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
           , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
           , ( Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
             , bool )
             Import.Types.Opt.t
           , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
               Composition_types.Wrap.Proof_state.Deferred_values.Plonk
               .In_circuit
               .Lookup
               .t
             , bool )
             Import.Types.Opt.t
           , bool
           , 'max_proofs_verified
             Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
           , ( Limb_vector.Constant.Hex64.t
             , Composition_types.Digest.Limbs.n )
             Pickles_types.Vector.vec
           , ( 'b
             , ( Kimchi_pasta.Pallas_based_plonk.Proof.G.Affine.Stable.V1.t
               , 'actual_proofs_verified )
               Pickles_types.Vector.t
             , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
                   Import.Bulletproof_challenge.t
                 , 'e )
                 Pickles_types.Vector.t
               , 'actual_proofs_verified )
               Pickles_types.Vector.t )
             Proof.Base.Messages_for_next_proof_over_same_field.Step.t
           , Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
             Import.Types.Bulletproof_challenge.t
             Import.Types.Step_bp_vec.t
           , Import.Types.Branch_data.t )
           Import.Types.Wrap.Statement.In_circuit.t )
  -> Kimchi_pasta.Pallas_based_plonk.Keypair.t
  -> ( 'b
     , ( ( Impls.Wrap.Challenge.Constant.t
         , Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
         , Impls.Wrap.Field.Constant.t Pickles_types.Shifted_value.Type2.t
         , Impls.Wrap.Field.Constant.t Pickles_types.Shifted_value.Type2.t
           option
         , Impls.Step.Challenge.Constant.t Composition_types.Scalar_challenge.t
           Composition_types.Step.Proof_state.Deferred_values.Plonk.In_circuit
           .Lookup
           .t
           option
         , ( Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
             Import.Types.Bulletproof_challenge.t
           , Backend.Tock.Rounds.n )
           Pickles_types.Vector.t
         , Impls.Wrap.Digest.Constant.t
         , bool )
         Import.Types.Step.Proof_state.Per_proof.In_circuit.t
       , 'max_proofs_verified )
       Pickles_types.Vector.t
     , ( Kimchi_pasta.Basic.Fp.Stable.Latest.t
         * Kimchi_pasta.Basic.Fp.Stable.Latest.t
       , 'actual_proofs_verified )
       Pickles_types.Vector.t
     , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
           Import.Bulletproof_challenge.t
         , 'e )
         Pickles_types.Vector.t
       , 'actual_proofs_verified )
       Pickles_types.Vector.t
     , 'max_local_max_proofs_verifieds
       Pickles_types.Hlist.H1.T
         (Proof.Base.Messages_for_next_proof_over_same_field.Wrap)
       .t
     , ( ( Backend.Tock.Field.t
         , Backend.Tock.Field.t array )
         Pickles_types.Plonk_types.All_evals.t
       , 'max_proofs_verified )
       Pickles_types.Vector.t )
     Proof.Base.Step.t
  -> ( 'max_proofs_verified
       Proof.Base.Messages_for_next_proof_over_same_field.Wrap.t
     , ( 'b
       , ( Kimchi_pasta.Basic.Fp.Stable.Latest.t
           * Kimchi_pasta.Basic.Fp.Stable.Latest.t
         , 'actual_proofs_verified )
         Pickles_types.Vector.t
       , ( ( Import.Challenge.Constant.t Import.Scalar_challenge.t
             Import.Bulletproof_challenge.t
           , 'e )
           Pickles_types.Vector.t
         , 'actual_proofs_verified )
         Pickles_types.Vector.t )
       Proof.Base.Messages_for_next_proof_over_same_field.Step.t )
     Proof.Base.Wrap.t
     Promise.t

val combined_inner_product :
     env:Backend.Tick.Field.t Plonk_checks.Scalars.Env.t
  -> domain:< shifts : Backend.Tick.Field.t array ; .. >
  -> ft_eval1:Backend.Tick.Field.t
  -> actual_proofs_verified:
       (module Pickles_types.Nat.Add.Intf with type n = 'actual_proofs_verified)
  -> ( Backend.Tick.Field.t * Backend.Tick.Field.t
     , Backend.Tick.Field.t array * Backend.Tick.Field.t array )
     Pickles_types.Plonk_types.All_evals.With_public_input.t
  -> old_bulletproof_challenges:
       ( (Backend.Tick.Field.t, 'a) Pickles_types.Vector.t
       , 'actual_proofs_verified )
       Pickles_types.Vector.t
  -> r:Backend.Tick.Field.t
  -> plonk:
       ( Backend.Tick.Field.t
       , Backend.Tick.Field.t
       , bool )
       Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
  -> xi:Backend.Tick.Field.t
  -> zeta:Backend.Tick.Field.t
  -> zetaw:Backend.Tick.Field.t
  -> Backend.Tick.Field.t

val challenge_polynomial :
     Backend.Tick.Field.t array
  -> (Backend.Tick.Field.t -> Backend.Tick.Field.t) Core_kernel.Staged.t

module Type1 :
    module type of
      Plonk_checks.Make
        (Pickles_types.Shifted_value.Type1)
        (Plonk_checks.Scalars.Tick)

module For_tests_only : sig
  type shifted_tick_field :=
    Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t

  type scalar_challenge_constant =
    Import.Challenge.Constant.t Import.Scalar_challenge.t

  type deferred_values_and_hints =
    { x_hat_evals : Backend.Tick.Field.t * Backend.Tick.Field.t
    ; sponge_digest_before_evaluations : Backend.Tick.Field.t
    ; deferred_values :
        ( ( Import.Challenge.Constant.t
          , scalar_challenge_constant
          , shifted_tick_field
          , (shifted_tick_field, bool) Plonk_types.Opt.t
          , ( scalar_challenge_constant
              Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
              .Lookup
              .t
            , bool )
            Plonk_types.Opt.t
          , bool )
          Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
        , scalar_challenge_constant
        , shifted_tick_field
        , scalar_challenge_constant Import.Bulletproof_challenge.t
          Import.Types.Step_bp_vec.t
        , Import.Branch_data.t )
        Import.Types.Wrap.Proof_state.Deferred_values.t
    }

  val deferred_values :
       sgs:
         ( Kimchi_pasta_basic.Fq.Stable.Latest.t
           * Kimchi_pasta_basic.Fq.Stable.Latest.t
         , 'n )
         Pickles_types__Vector.T.t
    -> feature_flags:
         Pickles_types__Plonk_types.Opt.Flag.t
         Pickles_types__Plonk_types.Features.Stable.V1.t
    -> actual_feature_flags:bool Pickles_types__Plonk_types.Features.Stable.V1.t
    -> prev_challenges:
         ( (Backend.Tick.Field.t, 'a) Pickles_types__Vector.T.t
         , 'n )
         Pickles_types__Vector.T.t
    -> step_vk:
         ( Pasta_bindings.Fp.t
         , Kimchi_bindings.Protocol.SRS.Fp.t
         , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
         )
         Kimchi_types.VerifierIndex.verifier_index
    -> public_input:Pasta_bindings.Fp.t list
    -> proof:
         ( Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
         , Pasta_bindings.Fp.t
         , Pasta_bindings.Fp.t array )
         Pickles_types.Plonk_types.Proof.Stable.V2.t
    -> actual_proofs_verified:'n Pickles_types__Nat.t
    -> deferred_values_and_hints
end
