(** Equality between types *)

type ('a, 'b) t = T : ('a, 'a) t

val cast : ('a, 'b) t -> 'a -> 'b

