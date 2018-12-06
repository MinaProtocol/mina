open Async_kernel

exception Overflow

exception Multiple_reads_attempted

type crash = Overflow_behavior_crash

type drop_head = Overflow_behavior_drop_head

type _ overflow_behavior =
  | Crash : crash overflow_behavior
  | Drop_head : drop_head overflow_behavior

type synchronous = Type_synchronous

type _ buffered = Type_buffered

type (_, _) type_ =
  | Synchronous : (synchronous, unit Deferred.t) type_
  | Buffered :
      [`Capacity of int] * [`Overflow of 'b overflow_behavior]
      -> ('b buffered, unit) type_

module Reader : sig
  type 't t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

  val fold :
       ?consumer:Pipe.Consumer.t
    -> 'a t
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> 'b Deferred.t
  (** This also uses `fold_without_pushback`, see [iter] *)

  val iter :
       ?consumer:Pipe.Consumer.t
    -> ?continue_on_error:bool
    -> 'a t
    -> f:('a -> unit)
    -> unit Deferred.t
  (** This is equivalent to `iter_without_pushback` on a normal pipe,
   * iter_without_pushback lets you model CSP style communication patterns. If
   * we allow `iter` with a pushback, we can emulate "single-threadedness", a
   * behavior we don't need yet for strict pipes *)

  module Merge : sig
    val iter : 'a t list -> f:('a -> unit Deferred.t) -> unit Deferred.t

    val iter_sync : 'a t list -> f:('a -> unit) -> unit Deferred.t
  end

  (** A synchronous write on a pipe that is later forked resolves its deferred
   * when all readers take the message (assuming the readers obey the CSP-style
   * iter *)
  module Fork : sig
    val n : 'a t -> int -> 'a t list

    val two : 'a t -> 'a t * 'a t
  end
end

module Writer : sig
  type ('t, 'behavior, 'return) t

  val write : ('t, _, 'return) t -> 't -> 'return
end

val create :
     ('type_, 'write_return) type_
  -> 't Reader.t * ('t, 'type_, 'write_return) Writer.t

val transfer :
     'a Reader.t
  -> ('b, synchronous, unit Deferred.t) Writer.t
  -> f:('a -> 'b)
  -> unit Deferred.t
