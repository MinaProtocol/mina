(** Left or right *)

type ('a, 'b) t =
  | Left  of 'a
  | Right of 'b

val map : ('a, 'b) t -> l:('a -> 'c) -> r:('b -> 'c) -> 'c
