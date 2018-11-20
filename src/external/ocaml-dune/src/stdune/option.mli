(** Optional values *)

type 'a t = 'a option =
  | None
  | Some of 'a

module O : sig
  val (>>|) : 'a t -> ('a -> 'b  ) -> 'b t
  val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
end

val map  : 'a t -> f:('a -> 'b  ) -> 'b t
val bind : 'a t -> f:('a -> 'b t) -> 'b t

val iter : 'a t -> f:('a -> unit) -> unit

val value : 'a t -> default:'a -> 'a
val value_exn : 'a t -> 'a

val some : 'a -> 'a t
val some_if : bool -> 'a -> 'a t

val is_some : _ t -> bool
val is_none : _ t -> bool

val both : 'a t -> 'b t -> ('a * 'b) t

val to_list : 'a t -> 'a list

val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

val compare : ('a -> 'a -> Ordering.t) -> 'a t -> 'a t -> Ordering.t
