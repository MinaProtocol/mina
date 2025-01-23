open Core_kernel
open Async

module Make: functor (T: Binable.S) -> sig

    type t 

    (** Initialize the on-disk cache explicitly before interactions with it take place. *)
    val initialize : string -> (t, [> `Initialization_error of Error.t ]) Deferred.Result.t

    type id [@@deriving compare, equal, sexp, hash]

    (** Increment the cache ref count, saving a value if the ref count was 0. *)
    val put : t ->  T.t -> id
    
    (** Read from the cache, crashing if the value cannot be found. *)
    val get : t -> id -> T.t

end