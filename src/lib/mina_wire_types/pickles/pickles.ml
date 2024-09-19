open Utils

module M = struct
  module Backend = struct
    module Tick = struct
      module Field = struct
        module V1 = struct
          type t = Pasta_bindings.Fp.t
        end
      end
    end
  end

  module Wrap_wire_proof = struct
    type 'a columns_vec = ('a, Pickles_types.Nat.fifteen) Pickles_types.Vector.t

    type 'a quotient_polynomial_vec =
      ('a, Pickles_types.Nat.seven) Pickles_types.Vector.t

    type 'a permuts_minus_1_vec =
      ('a, Pickles_types.Nat.six) Pickles_types.Vector.t

    module Commitments = struct
      module V1 = struct
        type t =
          { w_comm : (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t) columns_vec
          ; z_comm : Pasta_bindings.Fp.t * Pasta_bindings.Fp.t
          ; t_comm :
              (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t)
              quotient_polynomial_vec
          }
      end
    end

    module Evaluations = struct
      module V1 = struct
        type t =
          { w : (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t) columns_vec
          ; coefficients :
              (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t) columns_vec
          ; z : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          ; s : (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t) permuts_minus_1_vec
          ; generic_selector : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          ; poseidon_selector : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          ; complete_add_selector : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          ; mul_selector : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          ; emul_selector : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          ; endomul_scalar_selector : Pasta_bindings.Fq.t * Pasta_bindings.Fq.t
          }
      end
    end

    module V1 = struct
      type t =
        { commitments : Commitments.V1.t
        ; evaluations : Evaluations.V1.t
        ; ft_eval1 : Pasta_bindings.Fq.t
        ; bulletproof :
            ( Pasta_bindings.Fp.t * Pasta_bindings.Fp.t
            , Pasta_bindings.Fq.t )
            Pickles_types.Plonk_types.Openings.Bulletproof.V1.t
        }
    end
  end

  module Proof = struct
    type challenge_constant =
      Pickles_types.Nat.two Pickles_limb_vector.Constant.t

    type tock_affine = Pasta_bindings.Fp.t * Pasta_bindings.Fp.t

    type 'a step_bp_vec = ('a, Pickles_types.Nat.sixteen) Pickles_types.Vector.t

    module Base = struct
      module Wrap = struct
        module V2 = struct
          type digest_constant =
            Pickles_types.Nat.four Pickles_limb_vector.Constant.t

          type ('messages_for_next_wrap_proof, 'messages_for_next_step_proof) t =
            { statement :
                ( challenge_constant
                , challenge_constant Kimchi_types.scalar_challenge
                , Snark_params.Tick.Field.t
                  Pickles_types.Shifted_value.Type1.V1.t
                , bool
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
                Pickles_types.Plonk_types.All_evals.V1.t
                  (* A job half-done may be worse than not done at all.
                     TODO: Migrate Plonk_types here, and actually include the
                     *wire* type, not this in-memory version.
                  *)
            ; proof : Wrap_wire_proof.V1.t
            }
        end
      end
    end

    type ('s, 'mlmb, _) with_data =
      | T :
          ( 'mlmb Pickles_reduced_messages_for_next_proof_over_same_field.Wrap.t
          , ( 's
            , (tock_affine, 'most_recent_width) Pickles_types.Vector.t
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

    module Proofs_verified_2 = struct
      module V2 = struct
        type nonrec t = (Pickles_types.Nat.two, Pickles_types.Nat.two) t
      end
    end
  end

  module Side_loaded = struct
    module Verification_key = struct
      module Vk = struct
        type t =
          ( Pasta_bindings.Fq.t
          , Kimchi_bindings.Protocol.SRS.Fq.t
          , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
          )
          Kimchi_types.VerifierIndex.verifier_index
      end

      type tock_curve_affine =
        Snark_params.Tick.Field.t * Snark_params.Tick.Field.t

      module V2 = struct
        type t =
          ( tock_curve_affine
          , Pickles_base.Proofs_verified.V1.t
          , Vk.t )
          Pickles_base.Side_loaded_verification_key.Poly.V2.t
      end

      module Max_width = struct
        type n = Pickles_types.Nat.two
      end
    end

    module Proof = struct
      module V2 = struct
        type t =
          (Verification_key.Max_width.n, Verification_key.Max_width.n) Proof.t
      end
    end
  end
end

module Types = struct
  module type S = sig
    module Proof : sig
      type ('a, 'b) t

      module Proofs_verified_2 : sig
        module V2 : sig
          type nonrec t = (Pickles_types.Nat.two, Pickles_types.Nat.two) t
        end
      end
    end

    module Side_loaded : sig
      module Verification_key : sig
        module Max_width : sig
          type n = Pickles_types.Nat.two
        end

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
      module Tick : sig
        module Field : sig
          module V1 : sig
            type t = Pasta_bindings.Fp.t
          end
        end
      end
    end
  end
end

module Concrete_ = M

module type Concrete =
  Types.S
    with type Side_loaded.Verification_key.V2.t =
      M.Side_loaded.Verification_key.V2.t
     and type Backend.Tick.Field.V1.t = Pasta_bindings.Fp.t
     and type ('a, 'b) Proof.t = ('a, 'b) M.Proof.t

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
