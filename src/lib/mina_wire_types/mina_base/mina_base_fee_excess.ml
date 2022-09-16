module Poly = struct
  module V1 = struct
    type ('token, 'fee) t =
      { fee_token_l : 'token
      ; fee_excess_l : 'fee
      ; fee_token_r : 'token
      ; fee_excess_r : 'fee
      }
  end
end

module V1 = struct
  type t =
    ( Mina_base_token_id.V1.t
    , (Currency.Fee.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t )
    Poly.V1.t
end
