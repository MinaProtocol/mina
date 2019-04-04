(** A broadcast_pipe allows multiple readers for a single writer without needing
to fork explicitly. It is always synchronous and always has at least one value
in it. *)

open Async_kernel

exception Already_closed

module Reader : sig
  (** The read side of the broadcast pipe *)
  type 'a t

  (** Iterate over the items in the pipe. The returned deferred is determined
      when the pipe closes. The first item f sees is the current item i.e. the
      one that would be returned by peek. If you use this with don't_wait_for, f
      will not be invoked until execution returns to the scheduler .*)
  val iter : 'a t -> f:('a -> unit Deferred.t) -> unit Deferred.t

  (** Fold over the items in the pipe. Same notes as iter. *)
  val fold : 'a t -> init:'b -> f:('b -> 'a -> 'b Deferred.t) -> 'b Deferred.t

  (** Peek at the latest value in the pipe. *)
  val peek : 'a t -> 'a
end

module Writer : sig
  (** The write side of the broadcast pipe *)
  type 'a t

  (** Write an item to the pipe. The returned Deferred with be determined when
      all downstream consumers have finished processing.
  *)
  val write : 'a t -> 'a -> unit Deferred.t

  (** Stop listening to the underlying pipe. This cascades to all listeners *)
  val close : 'a t -> unit
end

(** Create a shared pipe and seed it with 'a *)
val create : 'a -> 'a Reader.t * 'a Writer.t
