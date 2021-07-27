(** Generic caching library *)

open! Core

(** [memoize ~destruct ~expire f]
    memoizes the results of [f].

    @param expire Strategy used to prune out values from the cache
    - [`Keep_one]: only keeps the last result around
    - [`Keep_all]: (the default value) never delete any values from the cache
    - [`Lru n]: keep [n] values in the cache and them removes the least recently
    used

    @param destruct function called on every value we remove from the cache
*)
val memoize :
     ?destruct:('b -> unit)
  -> ?expire:[ `Lru of int | `Keep_all | `Keep_one ]
  -> ('a -> 'b)
  -> 'a
  -> 'b

(** Returns memoized version of any function with argument unit. In effect this
    builds a lazy value.*)
val unit : (unit -> 'a) -> unit -> 'a

(** {1 Exposed cache }

    These modules implement memoization and give you access to the cache. This,
    for instance, enables you to flush it.
*)

(** Least recently used caching *)
module Lru : sig
  type ('k, 'v) t

  type ('a, 'b) memo = ('a, ('b, exn) Result.t) t

  val find : ('k, 'v) t -> 'k -> 'v option

  val add : ('k, 'v) t -> key:'k -> data:'v -> unit

  val remove : ('k, _) t -> 'k -> unit

  val clear : (_, _) t -> unit

  val create : destruct:('v -> unit) option -> int -> ('k, 'v) t

  val call_with_cache : cache:('a, 'b) memo -> ('a -> 'b) -> 'a -> 'b

  val memoize :
    ?destruct:('b -> unit) -> ('a -> 'b) -> int -> ('a, 'b) memo * ('a -> 'b)
end

(** Full caching (never flushes out values automatically ) *)
module Keep_all : sig
  type ('k, 'v) t

  type ('a, 'b) memo = ('a, ('b, exn) Result.t) t

  val find : ('k, 'v) t -> 'k -> 'v option

  val add : ('k, 'v) t -> key:'k -> data:'v -> unit

  val remove : ('k, _) t -> 'k -> unit

  val clear : (_, _) t -> unit

  val create : destruct:('v -> unit) option -> ('k, 'v) t

  val call_with_cache : cache:('a, 'b) memo -> ('a -> 'b) -> 'a -> 'b

  val memoize :
    ?destruct:('b -> unit) -> ('a -> 'b) -> ('a, 'b) memo * ('a -> 'b)
end

(** {1  Generic caching}

    This enables you to implement your own caching strategy and store.

    Generic caching is based on separating the replacement policie and the
    store and tying them together with [Make].
*)

(** Replacement policy

    This dictates when elements will droped from the cache.
*)
module type Strategy = sig
  type 'a t

  (** This type is used to specify the signature of [cps_create]. For instance
      if [cps_create] takes two arguments of types [x] and [y]:
{[
  type 'a with_init_args : x -> y -> 'a
]}
  *)
  type 'a with_init_args

  (** [cps_create ~f ] is given in CPS form to enable chaining. (i.e. instead of
      directly returning a value it applies f to this value). *)
  val cps_create : f:(_ t -> 'b) -> 'b with_init_args

  (** Marks an element as "fresh". Returns a list of elements to be dropped from
      the store. *)
  val touch : 'a t -> 'a -> 'a list

  (** Informs the strategy that an element was removed from the store. *)
  val remove : 'a t -> 'a -> unit

  (** Inform the strategy that all the elements where dropped from the store. *)
  val clear : 'a t -> unit
end

(** Caching store

    A [Store] is the backend used to store the values in a cache. A store is
    a key/value associative table.
*)
module type Store = sig
  (** A key value store. *)
  type ('k, 'v) t

  type 'a with_init_args

  (** [cps_create] is given in CPS form to enable chaining.

      see {!Cache.Strategy.cps_create} for more information.
  *)
  val cps_create : f:((_, _) t -> 'b) -> 'b with_init_args

  (** Remove all the values from the store. *)
  val clear : ('k, 'v) t -> unit

  (** [set store ~key ~data] associated the [data] to [key]; remove any
      previously existing binding. *)
  val set : ('k, 'v) t -> key:'k -> data:'v -> unit

  (** [find store key] returns the value associated to [key] in [store].  *)
  val find : ('k, 'v) t -> 'k -> 'v option

  (** [data store] returns all values in [store]. *)
  val data : (_, 'v) t -> 'v list

  (** [remove store key] removes the binding for [key] in [store]. *)
  val remove : ('k, 'v) t -> 'k -> unit
end

(** The output signature of the functor {!Cache.Make} *)
module type S = sig
  (** A key value cache*)
  type ('k, 'v) t

  (** Used to specify the type of the {!create} and {!memoize} function. This
      describes the arguments required to initialise the caching strategy and
      the store. For instance if the store doesn't take any argument (eg.:
      {!Store.Table}) and the strategy takes an [int] (eg.: {!Strategy.Lru})
      this type will be:

{[
   type 'a with_init_args = int -> 'a
]}
  *)
  type 'a with_init_args

  type ('a, 'b) memo = ('a, ('b, exn) Result.t) t

  val find : ('k, 'v) t -> 'k -> 'v option

  val add : ('k, 'v) t -> key:'k -> data:'v -> unit

  val remove : ('k, _) t -> 'k -> unit

  val clear : (_, _) t -> unit

  val create : destruct:('v -> unit) option -> ('k, 'v) t with_init_args

  val call_with_cache : cache:('a, 'b) memo -> ('a -> 'b) -> 'a -> 'b

  val memoize :
       ?destruct:('b -> unit)
    -> ('a -> 'b)
    -> (('a, 'b) memo * ('a -> 'b)) with_init_args
end

(** Predefined strategies *)
module Strategy : sig
  (** Least recently used. *)
  module Lru : Strategy with type 'a with_init_args = int -> 'a

  (** Keep all the values*)
  module Keep_all : Strategy with type 'a with_init_args = 'a
end

(** Predefined stores *)
module Store : sig
  module Table : Store with type 'a with_init_args = 'a
end

module Make (Strat : Strategy) (Store : Store) :
  S with type 'a with_init_args = 'a Store.with_init_args Strat.with_init_args
