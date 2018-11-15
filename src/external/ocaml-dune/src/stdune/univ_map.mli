(** Universal maps *)

(** A universal map is a map that can store values for arbitrary
    keys. It is the the key that conveys the type of the data
    associated to it. *)
type t

module Key : sig
  type 'a t
  val create : name:string -> ('a -> Sexp.t) -> 'a t
end

val empty    : t
val is_empty : t -> bool
val mem      : t -> 'a Key.t -> bool
val add      : t -> 'a Key.t -> 'a -> t
val remove   : t -> 'a Key.t -> t
val find     : t -> 'a Key.t -> 'a option
val find_exn : t -> 'a Key.t -> 'a
val singleton : 'a Key.t -> 'a -> t

(** [superpose a b] is [b] augmented with bindings of [a] that are not
    in [b]. *)
val superpose : t -> t -> t

val to_sexp : t -> Sexp.t
