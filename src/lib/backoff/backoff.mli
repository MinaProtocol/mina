open Core_kernel
open Async_kernel

(** A strategy for computing exponential backoff delays with full jitter.

    [Strategy.t] is an opaque configuration object. Create one with
    {!create}, then pass it to one of the [retry] functions. The same
    strategy can be reused across multiple retry operations. *)
module Strategy : sig
  type t

  val create :
       base:Time_ns.Span.t
    -> max_delay:Time_ns.Span.t
    -> max_attempts:int option
    -> ?random_state:Random.State.t
    -> unit
    -> t
end

(** The signature required by {!Make} to instantiate the retry loop over
    a particular monad. *)
module type Monad = sig
  type 'a t

  val return : 'a -> 'a t

  val bind : 'a t -> f:('a -> 'b t) -> 'b t

  val sleep : Time_ns.Span.t -> unit t
end

(** [Make(M)] returns a module with a [retry] function that runs in the
    monad [M]. *)
module Make (M : Monad) : sig
  val retry :
       ?log_errors:bool
    -> Strategy.t
    -> logger:Logger.t
    -> f:(unit -> 'a Or_error.t M.t)
    -> 'a Or_error.t M.t
end

(** Pre-built instance of {!Make} for [Deferred.t]. *)
module Deferred : sig
  val retry :
       ?log_errors:bool
    -> Strategy.t
    -> logger:Logger.t
    -> f:(unit -> 'a Or_error.t Deferred.t)
    -> 'a Or_error.t Deferred.t
end
