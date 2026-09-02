module V2 = struct
  type t = (Currency.Fee.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
end
