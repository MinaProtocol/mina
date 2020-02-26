(* fork_id.mli *)

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving sexp]
  end
end]

type t = Stable.Latest.t [@@deriving sexp]

(** useful when deserializing, could be an invalid string *)
val is_valid : t -> bool

val create : string -> t

val get_current : unit -> t

val set_current : t -> unit

val to_string : t -> string

val required_length : int

val empty : t
