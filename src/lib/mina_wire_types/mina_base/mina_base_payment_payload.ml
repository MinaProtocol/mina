module Poly = struct
  module V1 = struct
    type ('public_key, 'token_id, 'amount) t =
      { source_pk : 'public_key
      ; receiver_pk : 'public_key
      ; token_id : 'token_id
      ; amount : 'amount
      }
  end

  module V2 = struct
    type ('public_key, 'amount) t =
      { source_pk : 'public_key; receiver_pk : 'public_key; amount : 'amount }
  end
end

module V1 = struct
  type t =
    ( Public_key.Compressed.V1.t
    , Mina_base_token_id.V1.t
    , Currency.Amount.V1.t )
    Poly.V1.t
end

module V2 = struct
  type t = (Public_key.Compressed.V1.t, Currency.Amount.V1.t) Poly.V2.t
end
