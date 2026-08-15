open Pickles_types

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
  -> (   ( Impls.Wrap.Impl.Field.t Pickles_types.Shifted_value.Type1.t
           Import.Types.Wrap_plonk_iop.In_circuit.Wrap.t
         , Impls.Wrap.Impl.Field.t Pickles_types.Shifted_value.Type1.t )
         Import.Types.Wrap_statement.Wrap.t
      -> unit )
  -> typ:('a, 'app_state) Impls.Step.Typ.t
  -> step_vk:Kimchi_bindings.Protocol.VerifierIndex.Fp.t
  -> actual_wrap_domains:(Core_kernel.Int.t, 'c) Pickles_types.Vector.t
  -> step_plonk_indices:'d
  -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
  -> actual_feature_flags:bool Plonk_types.Features.t
  -> ?tweak_statement:
       (   ( 'max_proofs_verified
           , 'app_state
           , 'actual_proofs_verified
           , 'bp_chal_length )
           Import.Types.Wrap_statement.In_circuit.Unhashed.t
        -> ( 'max_proofs_verified
           , 'app_state
           , 'actual_proofs_verified
           , 'bp_chal_length )
           Import.Types.Wrap_statement.In_circuit.Unhashed.t )
  -> Backend.Tock.Keypair.t
  -> ( 'app_state
     , 'max_proofs_verified
     , 'actual_proofs_verified
     , 'bp_chal_length
     , 'max_local_max_proofs_verifieds )
     Proof.Base.Step.Specialised.t
  -> ( 'app_state
     , 'max_proofs_verified
     , 'actual_proofs_verified
     , 'bp_chal_length )
     Proof.Base.Wrap.Specialised.t
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
  -> plonk:Composition_types.Wrap_plonk_iop.Minimal.Tick.poly_t
  -> xi:Backend.Tick.Field.t
  -> zeta:Backend.Tick.Field.t
  -> zetaw:Backend.Tick.Field.t
  -> Backend.Tick.Field.t

(** Evaluates the challenge polynomial [b(X) = prod_i (1 + u_i * X^{2^{k-1-i}})]
    specialized for Tick field. Used for out-of-circuit computation.
    See {!module:Pickles} glossary for details on the challenge polynomial. *)
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
        ( shifted_tick_field
          Import.Types.Wrap_plonk_iop.In_circuit.Constant_opt.t
        , shifted_tick_field )
        Import.Types.Wrap_proof_state.Deferred_values.Constant.poly_t
    }

  val deferred_values :
       sgs:(Backend.Tick.Curve.Affine.t, 'n) Vector.t
    -> actual_feature_flags:bool Plonk_types.Features.t
    -> prev_challenges:((Backend.Tick.Field.t, 'a) Vector.t, 'n) Vector.t
    -> step_vk:Kimchi_bindings.Protocol.VerifierIndex.Fp.t
    -> public_input:Backend.Tick.Field.t list
    -> proof:Backend.Tick.Proof.with_public_evals
    -> actual_proofs_verified:'n Nat.t
    -> deferred_values_and_hints
end
