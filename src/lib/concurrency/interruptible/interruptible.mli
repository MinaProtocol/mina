open Core_kernel
open Async_kernel

(** The type of interruptible computations.
    [('a, 's) t] represents a computation that produces a value of type ['a],
    but which may be interrupted by a signal of type ['s].

    A computation is finished when it has completed and produced a result, or
    when it has been interrupted.  A finished computation may still be
    interrupted, which will cause any computations that depend on it (via
    [map], [bind], etc.) to also become interrupted.
    The result of an interruptible computation cannot be retrieved once it has
    been interrupted.
*)
type ('a, 's) t

include Monad.S2 with type ('a, 's) t := ('a, 's) t

val map_signal : ('a, 's) t -> f:('s -> 's1) -> ('a, 's1) t

(** [don't_wait_for x] schedules [x] to be run in another thread, ignoring its
    value and continuing in the current thread.
*)
val don't_wait_for : (unit, 's) t -> unit

(** [finally x ~f] schedules [f] to be run after [x] has finished, regardless
    of whether [x] completed its computation was interrupted.
*)
val finally : ('a, 's) t -> f:(unit -> unit) -> ('a, 's) t

(** [lift d interrupt] creates an interruptible computation from the deferred
    computation [d]. When [interrupt] is resolved, the computation and any
    values that depend on it become interrupted.
*)
val lift : 'a Deferred.t -> 's Deferred.t -> ('a, 's) t

(** [uninterruptible d] wraps the deferred computation [d]. Once [d] is
    started, it will be run until it produces a result.

    Interrupting a computation during an [uninterruptible] block will still
    cause the result of the [uninterruptible] block to be discarded.
*)
val uninterruptible : 'a Deferred.t -> ('a, 's) t

(** [force x] returns a deferred computation which resolves when the
    interruptible computation [x] has completed.

    If [x] has finished and produced a result, but has been subsequently
    interrupted, [force x] will resolve to the interrupted state instead of the
    result.
*)
val force : ('a, 's) t -> ('a, 's) Deferred.Result.t

module Result : sig
  type nonrec ('a, 'b, 's) t = (('a, 'b) Result.t, 's) t

  include Monad.S3 with type ('a, 'b, 's) t := ('a, 'b, 's) t
end

module Or_error : sig
  type nonrec ('a, 's) t = ('a Or_error.t, 's) t

  include Monad.S2 with type ('a, 's) t := ('a, 's) t
end

module Deferred_let_syntax : sig
  module Let_syntax : sig
    val return : 'a -> ('a, _) t

    val bind : 'a Deferred.t -> f:('a -> ('b, 's) t) -> ('b, 's) t

    val map : 'a Deferred.t -> f:('a -> 'b) -> ('b, _) t

    val both : 'a Deferred.t -> 'b Deferred.t -> ('a * 'b, _) t

    module Open_on_rhs = Deferred.Let_syntax
  end
end
