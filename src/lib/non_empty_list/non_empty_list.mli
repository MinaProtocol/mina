(** A non-empty list that is safe by construction. *)

type 'a t [@@deriving sexp, compare, eq, hash]

val head : 'a t -> 'a
(** The first element of the container *)

val tail : 'a t -> 'a list
(** The zero or more tail elements of the container *)

val map : 'a t -> f:('a -> 'b) -> 'b t
(** Apply a function to each element of the non empty list *)

(* The following functions are computed from {!module:Base.Container.Make}. See
 * {!modtype:Base.Container_intf} for more information *)

val find : 'a t -> f:('a -> bool) -> 'a option

val find_map : 'a t -> f:('a -> 'b option) -> 'b option

val fold : 'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum

val iter : 'a t -> f:('a -> unit) -> unit

val length : 'a t -> int
