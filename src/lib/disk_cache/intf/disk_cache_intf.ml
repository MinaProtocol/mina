open Core_kernel
open Async_kernel

module type F = functor (Data : Binable.S) -> sig
  type t

  (** Initialize the on-disk cache explicitly before interactions with it take place. *)
  val initialize :
       string
    -> logger:Logger.t
    -> (t, [> `Initialization_error of Error.t ]) Deferred.Result.t

  type id

  (** Put the value to disk, return an identifier that is associated with a special handler in GC. *)
  val put : t -> Data.t -> id

  (** Read from the cache, crashing if the value cannot be found. *)
  val get : t -> id -> Data.t

  val count : t -> int
end
