open Core

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Bignum.Bigint.t * Bignum.Bigint.t
      [@@deriving sexp, eq, compare, hash]
    end
    type t = Bignum.Bigint.Stable.V1.t * Bignum.Bigint.Stable.V1.t
    [@@deriving bin_io]
    let equal (b1, b2) (b1', b2') =
      Bignum.Bigint.Stable.V1.compare b1 b1' = 0 &&
      Bignum.Bigint.Stable.V1.compare b2 b2' = 0

    include (T : (module type of T with type t := t))
  end
end

include Stable.V1

open Snark_params.Tick

type var = Boolean.var list * Boolean.var list
let typ : (var, t) Typ.t = Schnorr.Signature.typ
