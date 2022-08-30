open Utils

module Types : sig
  module type S = sig
    module Side_loaded : sig
      module Verification_key : V2S0
    end

    module Backend : sig
      module Tick : sig
        module Field : sig
          module V1 : sig
            type t = Pasta_bindings.Fp.t
          end
        end
      end
    end

    module Proof : sig end
  end
end

module Concrete_ : sig
  module Side_loaded : sig
    module Verification_key : sig
      module Vk : sig
        type t =
          ( Pasta_bindings.Fq.t
          , Kimchi_bindings.Protocol.SRS.Fq.t
          , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
          )
          Kimchi_types.VerifierIndex.verifier_index
      end

      type tock_curve_affine =
        Snark_params.Tick.Field.t * Snark_params.Tick.Field.t

      module V2 : sig
        type t =
          ( tock_curve_affine
          , Pickles_base.Proofs_verified.V1.t
          , Vk.t )
          Pickles_base.Side_loaded_verification_key.Poly.V2.t
      end
    end
  end

  module Backend : sig
    module Tick : sig
      module Field : sig
        module V1 : sig
          type t = Pasta_bindings.Fp.t
        end
      end
    end
  end

  module Proof : sig
    module Base : sig
      module Wrap : sig
        module V2 : sig
          type challenge_constant =
            Pickles_limb_vector.Constant.Make(Pickles_types.Nat.N2).t

          type digest_constant =
            Pickles_limb_vector.Constant.Make(Pickles_types.Nat.N4).t

          type 'a step_bp_vec =
            'a Kimchi_pasta.Basic.Rounds.Step_vector.Stable.V1.t

          type tock_affine = Pasta_bindings.Fp.t * Pasta_bindings.Fp.t

          type tock_proof =
            ( tock_affine
            , Pasta_bindings.Fq.t
            , Pasta_bindings.Fq.t array )
            Pickles_types.Plonk_types.Proof.Stable.V2.t

          type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
            { statement :
                ( challenge_constant
                , challenge_constant Kimchi_types.scalar_challenge
                , Snark_params.Tick.Field.t Pickles_types.Shifted_value.Type1.t
                , 'messages_for_next_wrap_proof
                , digest_constant
                , 'messages_for_next_step_proof
                , challenge_constant Kimchi_types.scalar_challenge
                  Pickles_bulletproof_challenge.V1.t
                  step_bp_vec
                , Pickles_composition_types.Branch_data.V1.t )
                Pickles_composition_types.Wrap.Statement.Minimal.V1.t
            ; prev_evals :
                ( Snark_params.Tick.Field.t
                , Snark_params.Tick.Field.t array )
                Pickles_types.Plonk_types.All_evals.t
            ; proof : tock_proof
            }
        end
      end
    end
  end
end

module M : Types.S

module type Concrete =
  Types.S
    with type Side_loaded.Verification_key.V2.t =
      Concrete_.Side_loaded.Verification_key.V2.t
     and type Backend.Tick.Field.V1.t = Pasta_bindings.Fp.t

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include
  Types.S with module Side_loaded = M.Side_loaded and module Backend = M.Backend
