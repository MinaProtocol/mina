(** Result type *)

type ('a, 'error) t = ('a, 'error) Dune_caml.result =
  | Ok    of 'a
  | Error of 'error

val ok : 'a -> ('a, _) t

val is_ok    : _ t -> bool
val is_error : _ t -> bool

val ok_exn : ('a, exn) t -> 'a

module O : sig
  val ( >>| ) : ('a, 'error) t -> ('a -> 'b) -> ('b, 'error) t
  val ( >>= ) : ('a, 'error) t -> ('a -> ('b, 'error) t) -> ('b, 'error) t
end

val map  : ('a, 'error) t -> f:('a -> 'b) -> ('b, 'error) t
val bind : ('a, 'error) t -> f:('a -> ('b, 'error) t) -> ('b, 'error) t

val map_error : ('a, 'error1) t -> f:('error1 -> 'error2) -> ('a, 'error2) t

(** Produce [Error <message>] *)
val errorf : ('a, unit, string, (_, string) t) format4 -> 'a

(** For compatibility with some other code *)
type ('a, 'error) result = ('a, 'error) t

module List : sig
  val map : 'a list -> f:('a -> ('b, 'e) t) -> ('b list, 'e) t

  val all : ('a, 'error) t list -> ('a list, 'error) t

  val iter : 'a list -> f:('a -> (unit, 'error) t) -> (unit, 'error) t

  val concat_map
    :  'a list
    -> f:('a -> ('b list, 'error) t)
    -> ('b list, 'error) t

  val fold_left
    :  'a list
    -> f:('acc -> 'a -> ('acc, 'c) result)
    -> init:'acc
    -> ('acc, 'c) result
end
