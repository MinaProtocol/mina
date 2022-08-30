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

    type 'a wrap_bp_vec = 'a Pickles_types.Vector.Vector_15.t

    type t =
      challenge_constant Kimchi_types.scalar_challenge
      Pickles_bulletproof_challenge.V1.t
      wrap_bp_vec
  end
end
