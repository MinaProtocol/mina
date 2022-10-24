open Utils

module Types : sig
  module type S = sig
    module Proof : S2

    module Side_loaded : sig
      module Verification_key : sig
        module Max_width : module type of Pickles_types.Nat.N2

        module V2 : sig
          type t
        end
      end

      module Proof : sig
        module V2 : sig
          type t =
            (Verification_key.Max_width.n, Verification_key.Max_width.n) Proof.t
        end
      end
    end

    module Backend : sig
      module Step : sig
        module Field : sig
          module V1 : sig
            type t = Pasta_bindings.Fp.t
          end
        end
      end
    end
  end
end

(** This module contains types that are normally hidden from the {!Pickles}
    interface, but that we need to expose in order for the {!Pickles}
    implementation to add type equalities to them, since they are later used to
    construct other types that are public.

    There should be {b no} reference to {!Concrete_} outside of the {!Pickles}
    implementation. *)
module Concrete_ : sig
  module Backend : sig
    module Step : sig
      module Field : sig
        module V1 : sig
          type t = Pasta_bindings.Fp.t
        end
      end
    end
  end

  module Proof : sig
    (* We define some type aliases directly *)
    type challenge_constant =
      Pickles_limb_vector.Constant.Make(Pickles_types.Nat.N2).t

    type wrap_affine = Pasta_bindings.Fp.t * Pasta_bindings.Fp.t

    type 'a step_bp_vec = 'a Kimchi_pasta.Basic.Rounds.Step_vector.Stable.V1.t

    module Base : sig
      module Wrap : sig
        module V2 : sig
          type digest_constant =
            Pickles_limb_vector.Constant.Make(Pickles_types.Nat.N4).t

          type wrap_proof =
            ( wrap_affine
            , Pasta_bindings.Fq.t
            , Pasta_bindings.Fq.t array )
            Pickles_types.Plonk_types.Proof.Stable.V2.t

          type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
            { statement :
                ( challenge_constant
                , challenge_constant Kimchi_types.scalar_challenge
                , Snark_params.Step.Field.t Pickles_types.Shifted_value.Type1.t
                , 'messages_for_next_wrap_proof
                , digest_constant
                , 'messages_for_next_step_proof
                , challenge_constant Kimchi_types.scalar_challenge
                  Pickles_bulletproof_challenge.V1.t
                  step_bp_vec
                , Pickles_composition_types.Branch_data.V1.t )
                Pickles_composition_types.Wrap.Statement.Minimal.V1.t
            ; prev_evals :
                ( Snark_params.Step.Field.t
                , Snark_params.Step.Field.t array )
                Pickles_types.Plonk_types.All_evals.t
            ; proof : wrap_proof
            }
        end
      end
    end

    type ('s, 'mlmb, _) with_data =
      | T :
          ( 'mlmb Pickles_reduced_messages_for_next_proof_over_same_field.Wrap.t
          , ( 's
            , (wrap_affine, 'most_recent_width) Pickles_types.Vector.t
            , ( challenge_constant Kimchi_types.scalar_challenge
                Pickles_bulletproof_challenge.V1.t
                step_bp_vec
              , 'most_recent_width )
              Pickles_types.Vector.t )
            Pickles_reduced_messages_for_next_proof_over_same_field.Step.V1.t
          )
          Base.Wrap.V2.t
          -> ('s, 'mlmb, _) with_data

    type ('max_width, 'mlmb) t = (unit, 'mlmb, 'max_width) with_data
  end

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

      type wrap_curve_affine =
        Snark_params.Step.Field.t * Snark_params.Step.Field.t

      module V2 : sig
        type t =
          ( wrap_curve_affine
          , Pickles_base.Proofs_verified.V1.t
          , Vk.t )
          Pickles_base.Side_loaded_verification_key.Poly.V2.t
      end

      module Max_width = Pickles_types.Nat.N2
    end

    module Proof : sig
      module V2 : sig
        type t =
          (Verification_key.Max_width.n, Verification_key.Max_width.n) Proof.t
      end
    end
  end
end

module M : Types.S

module type Concrete =
  Types.S
    with type Side_loaded.Verification_key.V2.t =
      Concrete_.Side_loaded.Verification_key.V2.t
     and type Backend.Step.Field.V1.t = Pasta_bindings.Fp.t
     and type ('a, 'b) Proof.t = ('a, 'b) Concrete_.Proof.t

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include
  Types.S
    with module Proof = M.Proof
     and module Side_loaded = M.Side_loaded
     and module Backend = M.Backend
