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

  val to_linear_pipe : 't t -> 't Linear_pipe.Reader.t

  val of_linear_pipe : 't Linear_pipe.Reader.t -> 't t

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

  val fold : 'a t -> init:'b -> f:('b -> 'a -> 'b Deferred.t) -> 'b Deferred.t
  (** This is equivalent to CSP style communication pattern. This does not
   * delegate to [Pipe.iter] under the hood because that emulates a
   * "single-threadedness" with its pushback mechanism. We want more of a CSP
   * model. *)

  val fold_without_pushback :
       ?consumer:Pipe.Consumer.t
    -> 'a t
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> 'b Deferred.t
  (** This has similar semantics to [fold reader ~init ~f], but f isn't
   * deferred. This function delegates to [Pipe.fold_without_pushback] *)

  val iter : 'a t -> f:('a -> unit Deferred.t) -> unit Deferred.t
  (** This is a specialization of a fold for the common case of accumulating
   * unit. See [fold reader ~init ~f] *)

  val iter_without_pushback :
       ?consumer:Pipe.Consumer.t
    -> ?continue_on_error:bool
    -> 'a t
    -> f:('a -> unit)
    -> unit Deferred.t
  (** See [fold_without_pushback reader ~init ~f] *)

  val clear : _ t -> unit

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

  val partition_map3 :
       'a t
    -> f:('a -> [`Fst of 'b | `Snd of 'c | `Trd of 'd])
    -> 'b t * 'c t * 'd t
end

module Writer : sig
  type ('t, 'behavior, 'return) t

  val to_linear_pipe : ('t, 'behavior, 'return) t -> 't Linear_pipe.Writer.t

  val write : ('t, _, 'return) t -> 't -> 'return

  val close : (_, _, _) t -> unit

  val is_closed : (_, _, _) t -> bool
end

val create :
     ('type_, 'write_return) type_
  -> 't Reader.t * ('t, 'type_, 'write_return) Writer.t

val transfer :
     'a Reader.t
  -> ('b, synchronous, unit Deferred.t) Writer.t
  -> f:('a -> 'b)
  -> unit Deferred.t
