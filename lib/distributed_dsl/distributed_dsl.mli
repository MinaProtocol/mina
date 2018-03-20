open Core_kernel
open Async_kernel

module type Message_delay_intf = sig
  type message
  val delay : message -> Time.Span.t
end

module type Temporal_intf = sig
  type t
  val create : now:Time.Span.t -> t
  val tick_forwards : t -> by:Time.Span.t -> unit
end

module type Fake_transport_intf = sig
  include Node.Transport_intf
  include Temporal_intf with type t := t

  val stop_listening : t -> me:peer -> unit
end

module type Fake_timer_intf = sig
  include Node.Timer_intf
  include Temporal_intf with type t := t
end

module Fake_timer : Fake_timer_intf

module type Fake_transport_s =
  functor
    (Message : sig type t end)
    (Message_delay : Message_delay_intf with type message := Message.t)
    (Peer : Node.Peer_intf) -> Fake_transport_intf with type message := Message.t
                                                    and type peer := Peer.t

module type S =
  functor 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Message_delay : Message_delay_intf with type message := Message.t)
    (Peer : Node.Peer_intf)
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
    (Transport : Fake_transport_intf with type message := Message.t
                                      and type peer := Peer.t)
    -> sig

    type t

    module MyNode : Node.S with type message := Message.t
                            and type state := State.t
                            and type transport := Transport.t
                            and module Message_label := Message_label
                            and module Timer_label := Timer_label
                            and module Condition_label := Condition_label
                            and module Timer := Fake_timer

    module Identifier : sig type t end

    type change =
      | Delete of Identifier.t
      | Add of MyNode.t

    val loop : t -> stop : unit Deferred.t -> unit Deferred.t

    val change : t -> change list -> unit
  end

module Make : S

module Fake_transport : Fake_transport_s
