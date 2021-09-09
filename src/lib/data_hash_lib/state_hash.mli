(* state_hash.mli *)

[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

include Data_hash.Full_size

include Codable.Base58_check_intf with type t := t

val raw_hash_bytes : t -> string

val to_bytes : [`Use_to_base58_check_or_raw_hash_bytes]

(* value of type t, not a valid hash *)
val dummy : t

val zero : Field.t

val to_decimal_string : t -> string

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
