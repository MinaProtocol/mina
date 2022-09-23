module Step = struct
  module V1 = struct
    type ('s, 'challenge_polynomial_commitments, 'bpcs) t =
      { app_state : 's
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bpcs
      }
  end
end

module Wrap = struct
  module Challenges_vector = struct
    type challenge_constant =
      Pickles_limb_vector.Constant.Make(Pickles_types.Nat.N2).t

    type 'a wrap_bp_vec = 'a Kimchi_pasta.Basic.Rounds.Wrap_vector.Stable.V1.t

    type t =
      challenge_constant Kimchi_types.scalar_challenge
      Pickles_bulletproof_challenge.V1.t
      wrap_bp_vec
  end

  type 'max_local_max_proofs_verified t =
    ( Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
    , ( Challenges_vector.t
      , 'max_local_max_proofs_verified )
      Pickles_types.Vector.t )
    Pickles_composition_types.Wrap.Proof_state.Messages_for_next_wrap_proof.V1.t
end
