open Utils

module Branch_data : sig
  module Types : sig
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

  module M : Types.S

  module type Local_sig = Signature(Types).S

  module Make
      (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
    Signature(M).S

  include Types.S with module Domain_log2 = M.Domain_log2 and module V1 = M.V1
end

module Wrap : sig
  module Proof_state : sig
    module Messages_for_next_wrap_proof : sig
      module V1 : sig
        type ('g1, 'bulletproof_challenges) t =
          { challenge_polynomial_commitment : 'g1
          ; old_bulletproof_challenges : 'bulletproof_challenges
          }
      end
    end

    module Deferred_values : sig
      module Plonk : sig
        module Minimal : sig
          module V1 : sig
            type ('challenge, 'scalar_challenge) t =
              { alpha : 'scalar_challenge
              ; beta : 'challenge
              ; gamma : 'challenge
              ; zeta : 'scalar_challenge
              ; joint_combiner : 'scalar_challenge option
              }
          end
        end
      end

      module V1 : sig
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
    end

    module V1 : sig
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
  end

  module Statement : sig
    module V1 : sig
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

    module Minimal : sig
      module V1 : sig
        type ( 'challenge
             , 'scalar_challenge
             , 'fp
             , 'messages_for_next_wrap_proof
             , 'digest
             , 'messages_for_next_step_proof
             , 'bp_chals
             , 'index )
             t =
          ( ( 'challenge
            , 'scalar_challenge )
            Proof_state.Deferred_values.Plonk.Minimal.V1.t
          , 'scalar_challenge
          , 'fp
          , 'messages_for_next_wrap_proof
          , 'digest
          , 'messages_for_next_step_proof
          , 'bp_chals
          , 'index )
          V1.t
      end
    end
  end
end
