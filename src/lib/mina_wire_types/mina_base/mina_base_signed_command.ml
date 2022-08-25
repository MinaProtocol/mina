module Poly = struct
  module V1 = struct
    type ('payload, 'pk, 'signature) t =
      { payload : 'payload; signer : 'pk; signature : 'signature }
  end
end

module V1 = struct
  type t =
    ( Mina_base_signed_command_payload.V1.t
    , Public_key.V1.t
    , Mina_base_signature.V1.t )
    Poly.V1.t
end

module V2 = struct
  type t =
    ( Mina_base_signed_command_payload.V2.t
    , Public_key.V1.t
    , Mina_base_signature.V1.t )
    Poly.V1.t
end
