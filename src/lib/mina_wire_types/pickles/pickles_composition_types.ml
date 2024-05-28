open Utils

module Branch_data = struct
  module Types = struct
    module type S = sig
      module Domain_log2 : V1S0

      module V1 : sig
        type t =
          { proofs_verified : Pickles_base.Proofs_verified.V1.t
          ; domain_log2 : Domain_log2.V1.t
          }
      end
    end
  end

  module type Concrete = Types.S with type Domain_log2.V1.t = char

  module M = struct
    module Domain_log2 = struct
      module V1 = struct
        type t = char
      end
    end

    module V1 = struct
      type t =
        { proofs_verified : Pickles_base.Proofs_verified.V1.t
        ; domain_log2 : Domain_log2.V1.t
        }
    end
  end

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
    F (M)
  include M
end

module Wrap = struct
  module Proof_state = struct
    module Messages_for_next_wrap_proof = struct
      module V1 = struct
        type ('g1, 'bulletproof_challenges) t =
          { challenge_polynomial_commitment : 'g1
          ; old_bulletproof_challenges : 'bulletproof_challenges
          }
      end
    end

    module Deferred_values = struct
      module Plonk = struct
        module Minimal = struct
          module V1 = struct
            type ('challenge, 'scalar_challenge, 'bool) t =
              { alpha : 'scalar_challenge
              ; beta : 'challenge
              ; gamma : 'challenge
              ; zeta : 'scalar_challenge
              ; joint_combiner : 'scalar_challenge option
              ; feature_flags :
                  'bool Pickles_types.Plonk_types.Features.Stable.V1.t
              }
          end
        end
      end

      module V1 = struct
        type ( 'plonk
             , 'scalar_challenge
             , 'fp
             , 'bulletproof_challenges
             , 'branch_data )
             t =
          { plonk : 'plonk
          ; combined_inner_product : 'fp
          ; b : 'fp
          ; xi : 'scalar_challenge
          ; bulletproof_challenges : 'bulletproof_challenges
          ; branch_data : 'branch_data
          }
      end

      module Minimal = struct
        module V1 = struct
          type ( 'challenge
               , 'scalar_challenge
               , 'bool
               , 'bulletproof_challenges
               , 'branch_data )
               t =
            { plonk : ('challenge, 'scalar_challenge, 'bool) Plonk.Minimal.V1.t
            ; bulletproof_challenges : 'bulletproof_challenges
            ; branch_data : 'branch_data
            }
        end
      end
    end

    module V1 = struct
      type ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'bp_chals
           , 'index )
           t =
        { deferred_values :
            ( 'plonk
            , 'scalar_challenge
            , 'fp
            , 'bp_chals
            , 'index )
            Deferred_values.V1.t
        ; sponge_digest_before_evaluations : 'digest
        ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
        }
    end

    module Minimal = struct
      module V1 = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'bool
             , 'messages_for_next_wrap_proof
             , 'digest
             , 'bp_chals
             , 'index )
             t =
          { deferred_values :
              ( 'challenge
              , 'scalar_challenge
              , 'bool
              , 'bp_chals
              , 'index )
              Deferred_values.Minimal.V1.t
          ; sponge_digest_before_evaluations : 'digest
          ; messages_for_next_wrap_proof : 'messages_for_next_wrap_proof
          }
      end
    end
  end

  module Statement = struct
    module V1 = struct
      type ( 'plonk
           , 'scalar_challenge
           , 'fp
           , 'messages_for_next_wrap_proof
           , 'digest
           , 'messages_for_next_step_proof
           , 'bp_chals
           , 'index )
           t =
        { proof_state :
            ( 'plonk
            , 'scalar_challenge
            , 'fp
            , 'messages_for_next_wrap_proof
            , 'digest
            , 'bp_chals
            , 'index )
            Proof_state.V1.t
        ; messages_for_next_step_proof : 'messages_for_next_step_proof
        }
    end

    module Minimal = struct
      module V1 = struct
        type ( 'challenge
             , 'scalar_challenge
             , 'bool
             , 'messages_for_next_wrap_proof
             , 'digest
             , 'messages_for_next_step_proof
             , 'bp_chals
             , 'index )
             t =
          { proof_state :
              ( 'challenge
              , 'scalar_challenge
              , 'bool
              , 'messages_for_next_wrap_proof
              , 'digest
              , 'bp_chals
              , 'index )
              Proof_state.Minimal.V1.t
          ; messages_for_next_step_proof : 'messages_for_next_step_proof
          }
      end
    end
  end
end
