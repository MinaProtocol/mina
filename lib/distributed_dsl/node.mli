open Core_kernel
open Async_kernel

module type Transport_intf = sig
  type t
  type message
  type peer

  val send : t -> recipient:peer -> message -> unit Or_error.t Deferred.t
  val listen : t -> message Linear_pipe.Reader.t
end

module type Timer_intf = sig
  type tok
  val wait : Time.Span.t -> tok * unit Deferred.t
  val cancel : tok -> unit
end

module type S = sig
  type message
  type state
  module Message_label : Hashable.S
  module Timer_label : Hashable.S
  module Condition_label : Hashable.S
  module Timer : Timer_intf

  type condition = state -> bool

  type message_condition = message -> condition

  type transition = t -> state -> state Deferred.t
  and message_transition = t -> message -> state -> state Deferred.t
  and t =
    { state : state
    ; last_state : state option
    ; conditions : (condition * transition) Condition_label.Table.t
    ; message_pipe : message Linear_pipe.Reader.t
    ; message_handlers : (message_condition * message_transition) Message_label.Table.t
    ; triggered_timers_r : transition Linear_pipe.Reader.t
    ; triggered_timers_w : transition Linear_pipe.Writer.t
    ; timers : unit Deferred.t Timer_label.Table.t
    }

  type handle_command = Condition_label.t * condition * transition
  type message_command = Message_label.t * message_condition * message_transition

  val on
    : Condition_label.t
    -> condition
    -> f:transition
    -> handle_command

  val msg
    : Message_label.t
    -> message_condition
    -> f:message_transition
    -> message_command

  val timeout
    : t
    -> Timer_label.t
    -> Time.Span.t
    -> f:transition
    -> Timer.tok

  val next_ready : t -> unit Deferred.t

  val make_node 
    : messages : message Linear_pipe.Reader.t
    -> ?parent : t
    -> initial_state : state
    -> message_command list 
    -> handle_command list 
    -> t

  val step : t -> t Deferred.t
end

module type F =
  functor 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : Timer_intf)
    (Message_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Timer_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Condition_label : sig 
       type label [@@deriving enum, sexp]
       include Hashable.S with type t = label
     end)
    (Transport : Transport_intf with type message := Message.t 
                                 and type peer := Peer.t) 
    -> S with type message := Message.t
          and type state := State.t
          and module Timer := Timer
          and module Message_label := Message_label
          and module Timer_label := Timer_label
          and module Condition_label := Condition_label

module Make : F

