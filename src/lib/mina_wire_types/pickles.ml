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
end

module Types = struct
  module type S = sig
    module Side_loaded : sig
      module Verification_key : V2S0
    end
  end
end

module type Concrete =
  Types.S
    with type Side_loaded.Verification_key.V2.t =
      M.Side_loaded.Verification_key.V2.t

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
