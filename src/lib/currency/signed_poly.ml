open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('magnitude, 'sgn) t =
          ('magnitude, 'sgn) Mina_wire_types.Signed_poly.V1.t =
      { magnitude : 'magnitude; sgn : 'sgn }
    [@@deriving annot, sexp, hash, compare, equal, yojson, fields]
  end
end]

let map ~f { magnitude; sgn } = { magnitude = f magnitude; sgn }
