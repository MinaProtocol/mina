open Async_kernel
open Core_kernel

module type F = sig
  type 'a t

  val interrupt_ivar : unit Ivar.t

  (** [lift interrupt] creates an interruptible computation from the deferred
    computation [d].
  *)
  val lift : 'a Deferred.t -> 'a t

  (** [force x] returns a deferred computation which resolves when the
    interruptible computation [x] has completed.
    If [x] has finished and produced a result, but has been subsequently
    interrupted, [force x] will resolve to the interrupted state instead of the
    result.
  *)
  val force : 'a t -> ('a, unit) Deferred.Result.t

  (** [peek x] returns result of a computation if it was completed successfully.
    In case of interruption, it returns [Some (Error e)]. 
    If a computation was neither completed nor interrupted, [None] is returned.
  *)
  val peek : 'a t -> ('a, unit) Result.t option

  (** [finally x ~f] schedules [f] to be run after [x] has finished, regardless
    of whether [x] completed its computation was interrupted.
  *)
  val finally : 'a t -> f:(unit -> unit) -> 'a t

  include Monad.S with type 'a t := 'a t

  module Deferred_let_syntax : sig
    module Let_syntax : sig
      module Let_syntax : sig
        val return : 'a -> 'a t

        val bind : 'a Deferred.t -> f:('a -> 'b t) -> 'b t

        val map : 'a Deferred.t -> f:('a -> 'b) -> 'b t

        val both : 'a Deferred.t -> 'b Deferred.t -> ('a * 'b) t

        module Open_on_rhs = Deferred.Result.Let_syntax
      end
    end
  end

  module Result : sig
    type nonrec ('a, 'b) t = ('a, 'b) Result.t t

    include Monad.S2 with type ('a, 'b) t := ('a, 'b) t
  end
end
