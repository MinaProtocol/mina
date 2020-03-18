(* fork_id.mli *)

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving sexp, eq]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, eq]

val create_exn : string -> t

val create_opt : string -> t option

val get_current : unit -> t

val set_current : t -> unit

val get_next_opt : unit -> t option

val set_next_opt : t option -> unit

val empty : t

val to_string : t -> string

val required_length : int

(** useful when deserializing, could be an invalid string *)
val is_valid : t -> bool
