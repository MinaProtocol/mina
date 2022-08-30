open Utils

module Types : sig
  module type S = sig
    module Reduced_messages_for_next_proof_over_same_field :
        module type of Pickles_reduced_messages_for_next_proof_over_same_field

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
  module Reduced_messages_for_next_proof_over_same_field :
      module type of Pickles_reduced_messages_for_next_proof_over_same_field

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

  module Proof : sig end
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
