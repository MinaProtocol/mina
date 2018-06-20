type 'a t

val wrap : 'a array -> 'a t

val get : 'a t -> int -> 'a
