open Core_kernel

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Mina_wire_types.Sgn_type.Sgn.V1.t = Pos | Neg
    [@@deriving sexp, hash, compare, equal, yojson]
  end
end]
