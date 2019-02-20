open Async_kernel
open Pipe_lib

(** An (optionally empty) read-only mvar that can have multiple subscribers *)
type 'a t

module Listener : sig
  (** A listener wraps a pipe with a way to stop it *)
  type 'a t

  val pipe : 'a t -> 'a option Strict_pipe.Reader.t
  (** Get the buffered, drop-head, capacity 3 pipe *)

  val stop : 'a t -> unit
  (** Stop listening *)
end

val create : 'a option Mvar.Read_only.t -> 'a t
(** Share an mvar. *)

val observe : 'a t -> 'a Listener.t
(** Register a new listener onto the shared mvar. The pipe inside the listener
 * will fire whenever (1) an immediate write of the current mvar value and (2)
 * subsequent writes to the mvar. [Listener.stop] will cancel the listening.
*)

val peek : 'a t -> 'a option
(** Peek at the value in the mvar. *)

val close : 'a t -> unit
(** Stop listening to the underlying mvar. *)
