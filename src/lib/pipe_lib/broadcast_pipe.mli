(** A broadcast_pipe allows multiple readers for a single writer without needing to fork explicitly. It is always synchronous and always has at least one value in it. *)

open Async_kernel

exception Already_closed

module Reader : sig
  (** The read side of the broadcast pipe *)
  type 'a t

  val iter :
       'a t
    -> f:('a -> unit Deferred.t)
    -> unit Deferred.t
       * ('a, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t
  (** Same semantics as [Strict_pipe.iter], close the returned pipe to stop this
   * iter. *)

  val fold :
       'a t
    -> init:'b
    -> f:('b -> 'a -> 'b Deferred.t)
    -> 'b Deferred.t
       * ('a, Strict_pipe.synchronous, unit Deferred.t) Strict_pipe.Writer.t
  (** Same semantics as [Strict_pipe.fold], close the returned pipe to stop this
   * fold. *)

  val peek : 'a t -> 'a
  (** Peek at the latest value in the pipe. *)
end

module Writer : sig
  (** The write side of the broadcast pipe *)
  type 'a t

  val write : 'a t -> 'a -> unit Deferred.t

  val close : 'a t -> unit
  (** Stop listening to the underlying pipe. This cascades to all listeners *)
end

val create : 'a -> 'a Reader.t * 'a Writer.t
(** Create a shared pipe and seed it with 'a *)
