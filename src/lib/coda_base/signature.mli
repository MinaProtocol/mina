[%%import "/src/config.mlh"]

open Core

[%%if defined consensus_mechanism]

open Snark_params.Tick

[%%endif]

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Field.t * Inner_curve.Scalar.t
    [@@deriving sexp, eq, compare, hash]

    include Codable.S with type t := t
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq, compare, hash]

include Codable.S with type t := t

[%%if defined consensus_mechanism]

type var = Field.Var.t * Inner_curve.Scalar.var

[%%endif]

include Codable.Base58_check_base_intf with type t := t

val dummy : t
