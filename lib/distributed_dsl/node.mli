open Core_kernel
open Async_kernel

module type Transport_intf = sig
  type t
  type message
  type peer

  val send : t -> recipient:peer -> message -> unit Or_error.t Deferred.t
  val listen : t -> message Linear_pipe.Reader.t
end

module type S = sig
  type message
  type state
  module Condition_label : Hashable.S

  module Condition : sig
    type t
    type timer_tok

    type condition

    val timeout : Time.Span.t -> t
    val msg : (state -> message -> bool) -> t
    val predicate : (state -> bool) -> t

    (* or *)
    val ( + ) : t -> t -> t
    (* additive identity *)
    val never : t

    (* and *)
    val ( * ) : t -> t -> t
    (* multiplicative identity *)
    val always : t

    val check : t -> state -> message -> timer_tok list -> bool

    val wait_timers : t -> timer_tok Deferred.t
  end

  type t = 
    { state : state
    ; last_state : state
    ; conditions : (Condition.t * transition) Condition_label.Table.t
    ; message_pipe : message Linear_pipe.Reader.t
    ; work : transition Linear_pipe.Reader.t
    }
  and transition = t -> state -> state
  and override_transition = t -> original:transition -> state -> state

  type command =
    | On of Condition_label.t * Condition.t * transition
    | Override of Condition_label.t * transition

  val on
    : Condition_label.t
    -> Condition.t
    -> f:transition
    -> command

  val override
    : Condition_label.t
    -> f:override_transition
    -> command

  val make_node 
    : messages : message Linear_pipe.Reader.t
    -> ?parent : t
    -> initial_state : state
    -> command list 
    -> t

  val step : t -> t Deferred.t
end

module type F =
  functor 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : sig val wait : Time.Span.t -> unit Deferred.t end)
    (Condition_label : sig 
       type label [@@deriving enum]
       include Hashable.S with type t = label
     end)
    (Transport : Transport_intf with type message := Message.t 
                                 and type peer := Peer.t) 
    -> S with type message := Message.t
          and type state := State.t
          and module Condition_label := Condition_label

module Make : F

