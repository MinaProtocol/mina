open Pickles_types
open Import
open Backend

val expand_deferred :
     zk_rows:int
  -> evals:
       (Pasta_bindings.Fp.t, Pasta_bindings.Fp.t array) Plonk_types.All_evals.t
  -> old_bulletproof_challenges:
       ( Challenge.Constant.t Kimchi_types.scalar_challenge
         Bulletproof_challenge.t
         Step_bp_vec.t
       , 'most_recent_width )
       Vector.vec
  -> proof_state:
       ( Challenge.Constant.t
       , Challenge.Constant.t Kimchi_types.scalar_challenge
       , Pasta_bindings.Fp.t Shifted_value.Type1.t
       , bool
       , 'n Reduced_messages_for_next_proof_over_same_field.Wrap.t
       , Types.Digest.Constant.t
       , Challenge.Constant.t Kimchi_types.scalar_challenge
         Bulletproof_challenge.t
         Step_bp_vec.t
       , Branch_data.t )
       Types.Wrap_proof_state.Minimal.Poly.t
  -> ( ( Challenge.Constant.t
       , Challenge.Constant.t Kimchi_types.scalar_challenge
       , Pasta_bindings.Fp.t Shifted_value.Type1.t
       , 'a
       , Challenge.Constant.t Kimchi_types.scalar_challenge option
       , bool )
       Types.Wrap_plonk_iop.In_circuit.t
     , Pasta_bindings.Fp.t Shifted_value.Type1.t
     , Branch_data.t )
     Types.Wrap_proof_state.Deferred_values.Computed.t
