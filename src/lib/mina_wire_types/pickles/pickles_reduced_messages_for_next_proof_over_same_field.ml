module Step = struct
  module V1 = struct
    type ('s, 'challenge_polynomial_commitments, 'bpcs) t =
      { app_state : 's
      ; challenge_polynomial_commitments : 'challenge_polynomial_commitments
      ; old_bulletproof_challenges : 'bpcs
      }
  end
end
