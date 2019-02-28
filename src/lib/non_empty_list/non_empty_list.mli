(** A non-empty list that is safe by construction. *)

type 'a t [@@deriving sexp, compare, eq, hash, bin_io]

val init : 'a -> 'a list -> 'a t
(** Create a non-empty list by proving you have a head element *)

val singleton : 'a -> 'a t
(** Create a non-empty list with a single element *)

val uncons : 'a t -> 'a * 'a list
(** Deconstruct a non-empty list into the head and tail *)

val cons : 'a -> 'a t -> 'a t
(** Prepend a new element *)

val head : 'a t -> 'a
(** The first element of the container *)

val tail : 'a t -> 'a list
(** The zero or more tail elements of the container *)

val rev : 'a t -> 'a t
(** The reverse ordered list *)

val of_list_opt : 'a list -> 'a t option
(** Convert a list into a non-empty-list, returning [None] if the list is
 * empty *)

val tail_opt : 'a t -> 'a t option
(** Get the tail as a non-empty-list *)

val map : 'a t -> f:('a -> 'b) -> 'b t
(** Apply a function to each element of the non empty list *)

(* The following functions are computed from {!module:Base.Container.Make}. See
 * {!modtype:Base.Container_intf} for more information *)

val find : 'a t -> f:('a -> bool) -> 'a option

val find_map : 'a t -> f:('a -> 'b option) -> 'b option

val fold : 'a t -> init:'accum -> f:('accum -> 'a -> 'accum) -> 'accum

val iter : 'a t -> f:('a -> unit) -> unit

val length : 'a t -> int

val rev : 'a t -> 'a t

val to_list : 'a t -> 'a list
(** Note: This is O(1) not O(n) like on most container *)

val append : 'a t -> 'a t -> 'a t

val take : 'a t -> int -> 'a t option
