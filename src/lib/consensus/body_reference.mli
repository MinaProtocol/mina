open Snark_params.Step

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = Blake2.Stable.V1.t [@@deriving sexp, compare, yojson, equal, hash]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare, yojson, equal]

type var

val var_of_t : t -> var

val typ : (var, t) Typ.t

val var_to_input : var -> Field.Var.t Random_oracle.Input.Chunked.t

val to_input : t -> Field.t Random_oracle.Input.Chunked.t

val to_hex : t -> string

val of_hex_exn : string -> t

val to_raw_string : t -> string
