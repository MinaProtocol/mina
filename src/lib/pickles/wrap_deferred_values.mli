open Pickles_types
open Import
open Backend

val expand_deferred :
     evals:
       (Pasta_bindings.Fp.t, Pasta_bindings.Fp.t array) Plonk_types.All_evals.t
  -> old_bulletproof_challenges:
       ( Challenge.Constant.t Import.Scalar_challenge.t Bulletproof_challenge.t
         Step_bp_vec.t
       , 'most_recent_width )
       Vector.vec
  -> proof_state:
       ( Challenge.Constant.t
       , Challenge.Constant.t Import.Scalar_challenge.t
       , bool
       , 'n Reduced_messages_for_next_proof_over_same_field.Wrap.t
       , Types.Digest.Constant.t
       , Challenge.Constant.t Import.Scalar_challenge.t Bulletproof_challenge.t
         Step_bp_vec.t
       , Branch_data.t )
       Types.Wrap.Proof_state.Minimal.t
  -> ( ( Challenge.Constant.t
       , Challenge.Constant.t Import.Scalar_challenge.t
       , Pasta_bindings.Fp.t Shifted_value.Type1.t
       , Challenge.Constant.t Import.Scalar_challenge.t option
       , bool )
       Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
     , Challenge.Constant.t Import.Scalar_challenge.t
     , Pasta_bindings.Fp.t Shifted_value.Type1.t
     , (Pasta_bindings.Fp.t, Tick.Rounds.n) Vector.vec
     , Branch_data.t )
     Types.Wrap.Proof_state.Deferred_values.t
