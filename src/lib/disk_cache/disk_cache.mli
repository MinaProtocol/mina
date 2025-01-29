open Core_kernel
open Async

module Make : functor (T : Binable.S) -> sig
  type t

  (** Initialize the on-disk cache explicitly before interactions with it take place. *)
  val initialize :
       string
    -> logger:Logger.t
    -> (t, [> `Initialization_error of Error.t ]) Deferred.Result.t

  type id

  (** Put the value to disk, return an identifier that is associated with a special handler in GC. *)
  val put : t -> T.t -> id

  (** Read from the cache, crashing if the value cannot be found. *)
  val get : t -> id -> T.t

  val count : t -> int

  val iteri : t -> f:(int -> T.t -> [< `Continue | `Stop ]) -> unit

  module For_tests : sig
    val int_of_id : id -> int
  end
end
