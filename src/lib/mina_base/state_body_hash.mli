[%%import "/src/config.mlh"]

open Core

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

include Data_hash.Full_size

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = Field.t [@@deriving sexp, compare, hash, yojson]

    val to_latest : t -> t

    include Comparable.S with type t := t

    include Hashable_binable with type t := t
  end
end]

val dummy : t
