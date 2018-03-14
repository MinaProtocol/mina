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

  type condition = 
    | Interval of Time.Span.t
    | Timeout of Time.Span.t
    | Message of (message -> bool)
    | Predicate of (state -> bool)

  type t = 
    { state : state
    ; last_state : state
    ; conditions : (condition * transition) Condition_label.Table.t
    ; message_pipe : message Linear_pipe.Reader.t
    ; work : transition Linear_pipe.Reader.t
    }
  and transition = t -> state -> state
  and override_transition = t -> original:transition -> state -> state

  type command =
    | On of Condition_label.t * condition * transition
    | Override of Condition_label.t * transition

  val on
    : Condition_label.t
    -> condition
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

module Make 
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
= struct

    type condition = 
      | Interval of Time.Span.t
      | Timeout of Time.Span.t
      | Message of (Message.t -> bool)
      | Predicate of (State.t -> bool)

    type t = 
      { state : State.t
      ; last_state : State.t
      ; conditions : (condition * transition) Condition_label.Table.t
      ; message_pipe : Message.t Linear_pipe.Reader.t
      ; work : transition Linear_pipe.Reader.t
      }
    and transition = t -> State.t -> State.t
    and override_transition = t -> original:transition -> State.t -> State.t

    type command =
      | On of Condition_label.t * condition * transition
      | Override of Condition_label.t * transition

    let on label condition ~f = failwith "nyi"

    let override label ~f = failwith "nyi"

    let make_node ~messages ?parent ~initial_state conditions = failwith "nyi"

    let step t = failwith "nyi"
      (* if we called a transition recently, check all the conditions *)
      (* else if a timeout/interval is up, call the relevant transition *)
      (* else if message queue not empty, check all message conditions *)

end

