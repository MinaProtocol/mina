open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Mina_wire_types.Sgn_type.Sgn.V1.t = Pos | Neg
    [@@deriving sexp, hash, compare, equal, yojson]

    let to_latest = Fn.id
  end
end]
