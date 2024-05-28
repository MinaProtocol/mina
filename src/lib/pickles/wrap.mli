open Pickles_types
open Import

type scalar_challenge_constant = Challenge.Constant.t Scalar_challenge.t

val wrap :
     proof_cache:Proof_cache.t option
  -> max_proofs_verified:'max_proofs_verified Pickles_types.Nat.t
  -> (module Pickles_types.Hlist.Maxes.S
        with type length = 'max_proofs_verified
         and type ns = 'max_local_max_proofs_verifieds )
  -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
  -> dlog_plonk_index:
       Backend.Tock.Curve.Affine.t array
       Pickles_types.Plonk_verification_key_evals.t
  -> (   ( Impls.Wrap.Impl.Field.t
         , Impls.Wrap.Impl.Field.t Composition_types.Scalar_challenge.t
         , Impls.Wrap.Impl.Field.t Pickles_types.Shifted_value.Type1.t
         , ( Impls.Wrap.Impl.Field.t Scalar_challenge.t
           , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
             Snarky_backendless.Snark_intf.Boolean0.t )
           Pickles_types.Opt.t
         , Impls.Wrap.Impl.Boolean.var
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t
         , ( Impls.Wrap.Impl.field Snarky_backendless.Cvar.t Scalar_challenge.t
             Bulletproof_challenge.t
           , Nat.z Backend.Tick.Rounds.plus_n )
           Vector.t
         , Impls.Wrap.Impl.field Snarky_backendless.Cvar.t )
         Types.Wrap.Statement.In_circuit.t
      -> unit )
  -> typ:('a, 'b) Impls.Step.Typ.t
  -> step_vk:Kimchi_bindings.Protocol.VerifierIndex.Fp.t
  -> actual_wrap_domains:(int, 'c) Pickles_types.Vector.t
  -> step_plonk_indices:'d
  -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
  -> actual_feature_flags:bool Plonk_types.Features.t
  -> ?tweak_statement:
       (   ( Challenge.Constant.t
           , scalar_challenge_constant
           , Backend.Tick.Field.t Shifted_value.Type1.t
           , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
             , bool )
             Import.Types.Opt.t
           , bool
           , 'max_proofs_verified
             Reduced_messages_for_next_proof_over_same_field.Wrap.t
           , (int64, Types.Digest.Limbs.n) Vector.t
           , ( 'b
             , (Backend.Tock.Proof.G.Affine.t, 'actual_proofs_verified) Vector.t
             , ( ( Challenge.Constant.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , 'e )
                 Vector.t
               , 'actual_proofs_verified )
               Vector.t )
             Reduced_messages_for_next_proof_over_same_field.Step.t
           , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
             Step_bp_vec.t
           , Branch_data.t )
           Types.Wrap.Statement.In_circuit.t
        -> ( Challenge.Constant.t
           , scalar_challenge_constant
           , Pasta_bindings.Fp.t Shifted_value.Type1.t
           , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
             , bool )
             Import.Types.Opt.t
           , bool
           , 'max_proofs_verified
             Reduced_messages_for_next_proof_over_same_field.Wrap.t
           , (int64, Types.Digest.Limbs.n) Vector.t
           , ( 'b
             , (Backend.Tock.Proof.G.Affine.t, 'actual_proofs_verified) Vector.t
             , ( ( Challenge.Constant.t Scalar_challenge.t
                   Bulletproof_challenge.t
                 , 'e )
                 Vector.t
               , 'actual_proofs_verified )
               Vector.t )
             Reduced_messages_for_next_proof_over_same_field.Step.t
           , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
             Step_bp_vec.t
           , Branch_data.t )
           Types.Wrap.Statement.In_circuit.t )
  -> Backend.Tock.Keypair.t
  -> ( 'b
     , ( ( Challenge.Constant.t
         , Challenge.Constant.t Scalar_challenge.t
         , Impls.Wrap.Field.Constant.t Shifted_value.Type2.t
         , ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
           , Backend.Tock.Rounds.n )
           Vector.t
         , Impls.Wrap.Digest.Constant.t
         , bool )
         Types.Step.Proof_state.Per_proof.In_circuit.t
       , 'max_proofs_verified )
       Vector.t
     , (Backend.Tock.Proof.G.Affine.t, 'actual_proofs_verified) Vector.t
     , ( ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
         , 'e )
         Vector.t
       , 'actual_proofs_verified )
       Vector.t
     , 'max_local_max_proofs_verifieds
       Hlist0.H1(Reduced_messages_for_next_proof_over_same_field.Wrap).t
     , ( (Pasta_bindings.Fq.t, Pasta_bindings.Fq.t array) Plonk_types.All_evals.t
       , 'max_proofs_verified )
       Vector.t )
     Proof.Base.Step.t
  -> ( 'max_proofs_verified
       Reduced_messages_for_next_proof_over_same_field.Wrap.t
     , ( 'b
       , (Backend.Tock.Proof.G.Affine.t, 'actual_proofs_verified) Vector.t
       , ( ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
           , 'e )
           Vector.t
         , 'actual_proofs_verified )
         Vector.t )
       Reduced_messages_for_next_proof_over_same_field.Step.t )
     Proof.Base.Wrap.t
     Promise.t

val combined_inner_product :
     env:Backend.Tick.Field.t Plonk_checks.Scalars.Env.t
  -> domain:< shifts : Backend.Tick.Field.t array ; .. >
  -> ft_eval1:Backend.Tick.Field.t
  -> actual_proofs_verified:
       (module Pickles_types.Nat.Add.Intf with type n = 'actual_proofs_verified)
  -> ( Backend.Tick.Field.t array * Backend.Tick.Field.t array
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
  type shifted_tick_field =
    Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t

  type scalar_challenge_constant =
    Import.Challenge.Constant.t Import.Scalar_challenge.t

  type deferred_values_and_hints =
    { x_hat_evals : Backend.Tick.Field.t array * Backend.Tick.Field.t array
    ; sponge_digest_before_evaluations : Backend.Tick.Field.t
    ; deferred_values :
        ( ( Import.Challenge.Constant.t
          , scalar_challenge_constant
          , shifted_tick_field
          , (scalar_challenge_constant, bool) Opt.t
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
       sgs:(Backend.Tick.Proof.G.Affine.t, 'n) Vector.t
    -> actual_feature_flags:bool Plonk_types.Features.t
    -> prev_challenges:((Backend.Tick.Field.t, 'a) Vector.t, 'n) Vector.t
    -> step_vk:Kimchi_bindings.Protocol.VerifierIndex.Fp.t
    -> public_input:Backend.Tick.Field.t list
    -> proof:Backend.Tick.Proof.with_public_evals
    -> actual_proofs_verified:'n Nat.t
    -> deferred_values_and_hints
end
