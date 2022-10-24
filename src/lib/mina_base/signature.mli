[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Step

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Field.t * Inner_curve.Scalar.t
    [@@deriving sexp, equal, compare, hash]

    include Codable.S with type t := t
  end
end]

include Codable.S with type t := t

[%%ifdef consensus_mechanism]

type var = Field.Var.t * Inner_curve.Scalar.var

[%%endif]

include Codable.Base58_check_intf with type t := t

val dummy : t

(** Coding reflecting the RFC0038 spec *)
module Raw : sig
  val encode : t -> string

  val decode : string -> t option
end
