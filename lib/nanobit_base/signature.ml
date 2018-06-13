open Core

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Bignum_bigint.t * Bignum_bigint.t
      [@@deriving sexp, eq, compare, hash]
    end

    type t = Bignum_bigint.Stable.V1.t * Bignum_bigint.Stable.V1.t
    [@@deriving bin_io]

    let equal = T.equal

    include (T : module type of T with type t := t)
  end
end

include Stable.V1
open Snark_params.Tick

type var = Boolean.var list * Boolean.var list

let typ : (var, t) Typ.t = Schnorr.Signature.typ
