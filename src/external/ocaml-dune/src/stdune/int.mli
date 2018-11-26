type t = int
val compare : t -> t -> Ordering.t
val to_sexp : t -> Sexp.t

module Set : Set.S with type elt = t
module Map : Map.S with type key = t

val of_string_exn : string -> t

val to_string : t -> string

module Infix : Comparable.OPS with type t = t
