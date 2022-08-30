open Utils

module M = struct
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
    end
  end

  module Backend = struct
    module Tick = struct
      module Field = struct
        module V1 = struct
          type t = Pasta_bindings.Fp.t
        end
      end
    end
  end

  module Proof = struct
    type challenge_constant =
      Pickles_limb_vector.Constant.Make(Pickles_types.Nat.N4).t

    type 'a step_bp_vec = 'a Pickles_types.Vector.Vector_16.t
  end
end

module Types = struct
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

module Concrete_ = M

module type Concrete =
  Types.S
    with type Side_loaded.Verification_key.V2.t =
      M.Side_loaded.Verification_key.V2.t
     and type Backend.Tick.Field.V1.t = Pasta_bindings.Fp.t

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
