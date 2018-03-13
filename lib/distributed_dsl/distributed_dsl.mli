open Core_kernel
open Async_kernel

module type Transport_intf = sig
  type t
  type message
  type peer

  val send : t -> recipient:peer -> message -> unit Or_error.t Deferred.t
  val listen : t -> message Linear_pipe.Reader.t
end

module type S =
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
    -> sig

    type condition = 
      | Interval of Time.Span.t
      | Timeout of Time.Span.t
      | Message of Message.t
      | Predicate of (State.t -> bool)

    type t = 
      { state : State.t
      ; last_state : State.t
      ; conditions : edge Condition_label.Table.t
      ; message_pipe : Message.t Linear_pipe.Reader.t
      ; work : transition Linear_pipe.Reader.t
      }
    and transition = t -> State.t -> State.t
    and edge = condition * transition

    val on
      : condition
      -> f:transition
      -> edge

    val make_node 
      : messages : Message.t Linear_pipe.Reader.t
      -> edge list 
      -> t

    val step : t -> t

  end

module Make : S
