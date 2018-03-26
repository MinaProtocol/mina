open Core

module Stable = struct
  module V1 = struct
    type t = Bignum.Bigint.Stable.V1.t * Bignum.Bigint.Stable.V1.t
    [@@deriving sexp, bin_io, compare]
  end
end

include Stable.V1

open Snark_params.Tick

type var = Boolean.var list * Boolean.var list
let typ : (var, t) Typ.t = Schnorr.Signature.typ
