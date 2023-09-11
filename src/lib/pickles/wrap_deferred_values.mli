open Pickles_types
open Import
open Backend

val expand_deferred :
     evals:
       ( Backend.Tick.Field.t
       , Backend.Tick.Field.t array )
       Plonk_types.All_evals.t
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
       , Backend.Tick.Field.t Shifted_value.Type1.t
       , Challenge.Constant.t Import.Scalar_challenge.t option
       , bool )
       Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
     , Challenge.Constant.t Import.Scalar_challenge.t
     , Backend.Tick.Field.t Shifted_value.Type1.t
     , (Backend.Tick.Field.t, Tick.Rounds.n) Vector.vec
     , Branch_data.t )
     Types.Wrap.Proof_state.Deferred_values.t
