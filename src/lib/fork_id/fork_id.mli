(* fork_id.mli *)

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving sexp]
  end
end]

type t = Stable.Latest.t [@@deriving sexp]

val required_length : int

val create : string -> t

val to_string : t -> string

val empty : t
