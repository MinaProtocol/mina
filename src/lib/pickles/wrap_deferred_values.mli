open Pickles_types
open Import
open Backend

type sponge_input =
  | Sponge_input :
      { zk_rows : int
      ; evals :
          ( Pasta_bindings.Fp.t
          , Pasta_bindings.Fp.t array )
          Plonk_types.All_evals.t
      ; old_bulletproof_challenges :
          ( (Pasta_bindings.Fp.t, Nat.N16.n) Vector.vec
          , 'most_recent_width )
          Vector.vec
      ; proof_state :
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
          Types.Wrap.Proof_state.Minimal.t
      }
      -> sponge_input

val compute_sponge_input :
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
       Types.Wrap.Proof_state.Minimal.t
  -> sponge_input

val compute_xi_r_chal :
     sponge_input
  -> Challenge.Constant.t Kimchi_types.scalar_challenge
     * Challenge.Constant.t Kimchi_types.scalar_challenge

val expand_deferred :
     zk_rows:int
  -> evals:
       (Pasta_bindings.Fp.t, Pasta_bindings.Fp.t array) Plonk_types.All_evals.t
  -> old_bulletproof_challenges:
       ( (Pasta_bindings.Fp.t, Nat.N16.n) Vector.vec
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
       Types.Wrap.Proof_state.Minimal.t
  -> xi_r_chal:
       Challenge.Constant.t Kimchi_types.scalar_challenge
       * Challenge.Constant.t Kimchi_types.scalar_challenge
  -> ( ( Challenge.Constant.t
       , Challenge.Constant.t Kimchi_types.scalar_challenge
       , Pasta_bindings.Fp.t Shifted_value.Type1.t
       , 'a
       , Challenge.Constant.t Kimchi_types.scalar_challenge option
       , bool )
       Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
     , Challenge.Constant.t Kimchi_types.scalar_challenge
     , Pasta_bindings.Fp.t Shifted_value.Type1.t
     , (Pasta_bindings.Fp.t, Tick.Rounds.n) Vector.vec
     , Branch_data.t )
     Types.Wrap.Proof_state.Deferred_values.t
