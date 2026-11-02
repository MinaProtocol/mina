(** How the daemon finished with each block it was given: what became of its
    entry in the unprocessed transition cache, of its gossip validation
    callback, and of the attempt to add it to the transition frontier.

    Nothing is recorded unless a test asks for it, in which case the events are
    kept in memory in the order they happen. Comparing the record before and
    after a change shows whether the change kept every block's outcome. *)

type cache_outcome =
  [ `Consumed  (** Finished with by its owner. *)
  | `Failure  (** Invalidated. *)
  | `Unconsumed  (** Dropped, and found by the garbage collector. *) ]
[@@deriving sexp, equal, compare]

type callback_outcome = [ `Accept | `Reject | `Ignore | `Expired ]
[@@deriving sexp, equal, compare]

type source = [ `Gossip | `Catchup | `Internal ]
[@@deriving sexp, equal, compare]

type event =
  | Cache_removed of { state_hash : string; outcome : cache_outcome }
  | Callback_resolved of { state_hash : string; outcome : callback_outcome }
  | Frontier_add of { state_hash : string; source : source; added : bool }
      (** [added] is false when the add was skipped because the block's parent
          had left the frontier. *)
[@@deriving sexp, equal, compare]

(** Record the event that [event] builds, if a test is recording. [event] is
    only called then, so building it may be expensive. *)
val record : (unit -> event) -> unit

module For_tests : sig
  (** Run [f], and return its result along with the events recorded while it
      ran, oldest first. Recording doesn't nest. *)
  val recording : (unit -> 'a) -> 'a * event list

  (** As [recording], for an [f] that is a deferred computation. *)
  val recording_deferred :
       (unit -> 'a Async_kernel.Deferred.t)
    -> ('a * event list) Async_kernel.Deferred.t
end
