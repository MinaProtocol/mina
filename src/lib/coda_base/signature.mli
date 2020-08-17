[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Field.t * Inner_curve.Scalar.t
    [@@deriving sexp, eq, compare, hash]

    include Codable.S with type t := t
  end
end]

include Codable.S with type t := t

[%%ifdef consensus_mechanism]

type var = Field.Var.t * Inner_curve.Scalar.var

[%%endif]

include Codable.Base58_check_base_intf with type t := t

val dummy : t
