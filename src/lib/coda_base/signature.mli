open Core

type t = Snark_params.Tock.Field.t * Snark_params.Tock.Field.t
[@@deriving sexp, eq, compare, hash]

module Stable : sig
  module V1 : sig
    type t = Snark_params.Tock.Field.t * Snark_params.Tock.Field.t
    [@@deriving sexp, eq, bin_io, compare, hash]
  end
end

open Snark_params.Tick

type var = Inner_curve.Scalar.var * Inner_curve.Scalar.var

val dummy : t
