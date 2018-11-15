module Var : sig
  type t = string
  val compare : t -> t -> Ordering.t

  module Set : Set.S with type elt = t
end

type t

module Map : Map.S with type key = Var.t

val empty : t

val vars : t -> Var.Set.t

(** The environment when the process started *)
val initial : t

val to_unix : t -> string array

val get : t -> Var.t -> string option

val extend : t -> vars:string Map.t -> t

val extend_env : t -> t -> t

val add : t -> var:Var.t -> value:string -> t

val remove : t -> var:Var.t -> t

val diff : t -> t -> t

val update : t -> var:string -> f:(string option -> string option) -> t

val to_sexp : t -> Sexp.t

val of_string_map : string String.Map.t -> t

val iter : t -> f:(string -> string -> unit) -> unit

val pp : Format.formatter -> t -> unit

val cons_path : t -> dir:Path.t -> t

val path : t -> Path.t list
