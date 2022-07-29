(** The type of interruptible computations.
    ['a t] represents a computation that produces a value of type ['a],
    but which may be interrupted.
    A computation is finished when it has completed and produced a result, or
    when it has been interrupted. A finished computation may still be
    interrupted, which will cause any computations that depend on it (via
    [map], [bind], etc.) to also become interrupted.
    The result of an interruptible computation cannot be retrieved once it has
    been interrupted.

    The type is a synonym for [Deferred.Result.t]. It's to be manipulated with functions
    from an instantiated functor.
*)
type 'a t

module type F = Functor_type.F with type 'a t := 'a t

(** [don't_wait_for x] schedules [x] to be run in another thread, ignoring its
    value and continuing in the current thread.
*)
val don't_wait_for : unit t -> unit

(** [peek_result x] returns result of a computation if it was completed successfully.
  In case of interruption, it may return [None] or [Some a] if case both interruption
  and computation completion occurred. Use functor's [peek x] if it's important to
  distinguish between interrupted and completed results.

  If a computation was neither completed nor interrupted, [None] is returned.
*)
val peek_result : 'a t -> 'a option

val unit : unit t

module Make () : F
