module Proof_with_vk_hash = struct
  module V1 = struct
    type ('proof, 'hash) t = { proof : 'proof; verification_key_hash : 'hash }
  end
end

module V2 = struct
  type t =
    | Proof of
        ( Pickles.Side_loaded.Proof.V2.t
        , Snark_params.Tick.Field.t )
        Proof_with_vk_hash.V1.t
    | Signature of Mina_base_signature.V1.t
    | None_given
end
