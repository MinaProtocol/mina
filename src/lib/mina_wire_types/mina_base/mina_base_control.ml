module Poly = struct
  module V1 = struct
    type ('proof, 'signature) t =
      | Proof of 'proof
      | Signature of 'signature
      | None_given
  end
end

module V2 = struct
  type t = (Pickles.Side_loaded.Proof.V2.t, Mina_base_signature.V1.t) Poly.V1.t
end
