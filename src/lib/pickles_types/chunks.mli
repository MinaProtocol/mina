(** Representation chunks of data *)

(** {2 Base type} *)

[%%versioned:
module Stable : sig
  module V1 : sig
    (** The type is exposed as read-only [private] but if you find you need a
        function not provided by this module, typically one operating directly
        on arrays, please refrain from using it and do add it here.  *)
    type 'a t = private { data : 'a array }
    [@@unboxed] [@@deriving sexp, compare, hash, equal, yojson, hlist]
  end
end]

(** {2 Creation functions} *)

(** [of_array a] creates a chunk in from a given array.

    This function is safe: changes to the initial array will not be impact the
    newly created value of type [t].

    @raise Invalid_argument if [Array.length a = 0]
  *)
val of_array : 'a array -> 'a t

(** [create ~len v] creates chunks of length [len] with value [v] for each
    chunk.

    @raise Invalid_argument if [len] <= 0
*)
val create : len:int -> 'a -> 'a t

(** [length chunk] returns the number of elements in [chunk]. *)
val length : 'a t -> int

(** [hd chunk] gets the first element of [chunk]. 
    
    This function cannot fail since there is always at least one element. 
    See {!val:create}.
*)
val hd : 'a t -> 'a

(** [get chunk n] optionally gets the [n]th element of [chunk].

    Chunks are 0-indexed: the first element is at [0].
*)
val get : 'a t -> int -> 'a option

(** [get chunk n] gets the [n]th element of [chunk].

    Chunks are 0-indexed: the first element is at [0].

    @raise Invalid_argument if [n] is negative or >= [length chunk].
*)
val get_exn : 'a t -> int -> 'a

(** {2 Iterators} *)

val fold : 'a t -> init:'b -> f:('b -> 'a -> 'b) -> 'b

val map : 'a t -> f:('a -> 'b) -> 'b t

val map2_exn : 'a t -> 'b t -> f:('a -> 'b -> 'c) -> 'c t

val iter : 'a t -> f:('a -> unit) -> unit

(** {2 Converters} *)

(** [typ ~len etyp] *)
val typ :
     len:int
  -> ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

(** [to_list chunk] converts [chunk]'s data to a list representation. *)
val to_list : 'a t -> 'a list
