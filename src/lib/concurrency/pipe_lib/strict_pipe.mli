open Async_kernel

exception Overflow of string

exception Multiple_reads_attempted of string

type crash = Overflow_behavior_crash

type drop_head = Overflow_behavior_drop_head

type call = Overflow_behavior_call

type (_, _, _) overflow_behavior =
  | Crash : ('a, crash, unit) overflow_behavior
  | Drop_head : ('a -> unit) -> ('a, drop_head, unit) overflow_behavior
  | Call : ('a -> 'r) -> ('a, call, 'r option) overflow_behavior

type synchronous = Type_synchronous

type _ buffered = Type_buffered

(** A [('a, 'behavior, 'write_result) type_] is a representation of strict pipe types.
 *  ['a] is the type of data written over the pipe, ['behavior] is a type parameter for classifying
 *  which overflow behavior the pipe exhibits, and ['write_result] determines the return type of
 *  writing to the pipe.
 *)
type (_, _, _) type_ =
  | Synchronous : ('a, synchronous, unit Deferred.t) type_
  | Buffered :
      [ `Capacity of int ] * [ `Overflow of ('a, 'b, 'r) overflow_behavior ]
      -> ('a, 'b buffered, 'r) type_

module Reader : sig
  type 't t

  (* Using [`Eof | `Ok of 't] to mirror interface of Jane Street's Pipe read *)

  (** Read a single value from the pipe or fail if the pipe is closed *)
  val read : 't t -> [ `Eof | `Ok of 't ] Deferred.t

  val read' : 't t -> [ `Eof | `Ok of 't Base.Queue.t ] Deferred.t

  val to_linear_pipe : 't t -> 't Linear_pipe.Reader.t

  val of_linear_pipe : ?name:string -> 't Linear_pipe.Reader.t -> 't t

  val pipe_name : _ t -> string option

  val map : 'a t -> f:('a -> 'b) -> 'b t

  val filter_map : 'a t -> f:('a -> 'b option) -> 'b t

  (** This is equivalent to CSP style communication pattern. This does not
   * delegate to [Pipe.iter] under the hood because that emulates a
   * "single-threadedness" with its pushback mechanism. We want more of a CSP
   * model. *)
  val fold : 'a t -> init:'b -> f:('b -> 'a -> 'b Deferred.t) -> 'b Deferred.t

  (** Like `fold`, except that `f` can terminate the fold early *)
  val fold_until :
       'a t
    -> init:'b
    -> f:('b -> 'a -> [ `Continue of 'b | `Stop of 'c ] Deferred.t)
    -> [ `Eof of 'b | `Terminated of 'c ] Deferred.t

  (** This has similar semantics to [fold reader ~init ~f], but f isn't
   * deferred. This function delegates to [Pipe.fold_without_pushback] *)
  val fold_without_pushback :
       ?consumer:Pipe.Consumer.t
    -> 'a t
    -> init:'b
    -> f:('b -> 'a -> 'b)
    -> 'b Deferred.t

  (** This is a specialization of a fold for the common case of accumulating
   * unit. See [fold reader ~init ~f] *)
  val iter : 'a t -> f:('a -> unit Deferred.t) -> unit Deferred.t

  val iter' : 'a t -> f:('a Base.Queue.t -> unit Deferred.t) -> unit Deferred.t

  (** See [fold_without_pushback reader ~init ~f] *)
  val iter_without_pushback :
       ?consumer:Pipe.Consumer.t
    -> ?continue_on_error:bool
    -> 'a t
    -> f:('a -> unit)
    -> unit Deferred.t

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

    val three : 'a t -> 'a t * 'a t * 'a t
  end

  (** This function would take a pipe and split the reader side into 3 ends. The
   * `read`s to the new pipe have to be in the same order as the `write`s or else
   * there will be a deadlock. *)
  val partition_map3 :
       'a t
    -> f:('a -> [ `Fst of 'b | `Snd of 'c | `Trd of 'd ])
    -> 'b t * 'c t * 'd t
end

module Writer : sig
  type ('t, 'behavior, 'return) t

  val pipe_name : (_, _, _) t -> string option

  val to_linear_pipe : ('t, 'behavior, 'return) t -> 't Linear_pipe.Writer.t

  val write : ('t, _, 'return) t -> 't -> 'return

  val close : (_, _, _) t -> unit

  (** This function would first clear the pipe and then close it. *)
  val kill : (_, _, _) t -> unit

  val is_closed : (_, _, _) t -> bool
end

val create :
     ?name:string
  -> ?warn_on_drop:bool
  -> ('t, 'type_, 'write_return) type_
  -> 't Reader.t * ('t, 'type_, 'write_return) Writer.t

val transfer :
     'a Reader.t
  -> ('b, 'type_, 'writer_return) Writer.t
  -> f:('a -> 'b)
  -> unit Deferred.t

val transfer_while_writer_alive :
     'a Reader.t
  -> ('b, 'type_, 'writer_return) Writer.t
  -> f:('a -> 'b)
  -> unit Deferred.t
