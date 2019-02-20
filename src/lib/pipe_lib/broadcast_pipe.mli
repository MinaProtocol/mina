open Async_kernel

(** A broadcast_pipe allows multiple readers and is initialized from an mvar *)
type 'a t

val create : 'a option Mvar.Read_only.t -> 'a t
(** Share an mvar. *)

val iter :
     close:unit Deferred.t
  -> 'a t
  -> f:('a option -> unit Deferred.t)
  -> unit Deferred.t
(** Same semantics as [Strict_pipe.iter] except to close only this iteration
 * use the close [Deferred.t]. The [close] function on broadcast_pipe stops 
 * everyone. *)

val iter_without_pushback :
  close:unit Deferred.t -> 'a t -> f:('a option -> unit) -> unit Deferred.t
(** Same semantics as [Strict_pipe.iter_without_pushback] except to close only
 * this iteration use the close [Deferred.t]. The [close] function on
 * broadcast_pipe stops everyone. *)

val fold :
     close:unit Deferred.t
  -> 'a t
  -> init:'b
  -> f:('b -> 'a option -> 'b Deferred.t)
  -> 'b Deferred.t
(** Same semantics as [Strict_pipe.fold] except to close only this iteration
 * use the close [Deferred.t]. The [close] function on broadcast_pipe stops 
 * everyone. *)

val fold_without_pushback :
     close:unit Deferred.t
  -> 'a t
  -> init:'b
  -> f:('b -> 'a option -> 'b)
  -> 'b Deferred.t
(** Same semantics as [Strict_pipe.fold_without_pushback] except to close only
 * this iteration use the close [Deferred.t]. The [close] function on
 * broadcast_pipe stops everyone. *)

val peek : 'a t -> 'a option
(** Peek at the value in the mvar. *)

val close : 'a t -> unit
(** Stop listening to the underlying mvar. This cascades to all listeners *)
