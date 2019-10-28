open Core
open Snark_params.Tick

type t = Field.t * Inner_curve.Scalar.t [@@deriving sexp, eq, compare, hash]

include Codable.S with type t := t

module Stable : sig
  module V1 : sig
    type t = Field.t * Inner_curve.Scalar.t
    [@@deriving sexp, eq, bin_io, compare, hash, version]

    include Codable.S with type t := t
  end

  module Latest = V1
end

type var = Field.Var.t * Inner_curve.Scalar.var

include Codable.Base58_check_base_intf with type t := t

val dummy : t
