open Core

type t = Snarky.Bignum_bigint.t * Snarky.Bignum_bigint.t
[@@deriving sexp, eq, compare, hash]

module Stable : sig
  module V1 : sig
    type t = Snarky.Bignum_bigint.Stable.V1.t * Snarky.Bignum_bigint.Stable.V1.t
    [@@deriving sexp, eq, bin_io, compare, hash]
  end
end

open Snark_params.Tick

type var = Boolean.var list * Boolean.var list
val typ : (var, t) Typ.t
