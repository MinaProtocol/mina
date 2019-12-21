open Core_kernel
include Functor.Make (Snark_params.Tick)
module Functor = Functor

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Sgn_type.Sgn.Stable.V1.t = Pos | Neg
    [@@deriving sexp, hash, compare, eq, yojson]

    let to_latest = Fn.id
  end
end]
