open Core_kernel
open Async_kernel

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
    (Transport : Node.Transport_intf with type message := Message.t 
                                      and type peer := Peer.t) 
    (Node : Node.S with type message := Message.t
                    and type state := State.t
                    and module Condition_label := Condition_label)
    -> sig

    type t = 
      { nodes : Node.t list }

    type change = 
      | Delete of int
      | Add of Node.t

    type changes = State.t list -> change list

    val step : t -> t Deferred.t

    val loop : t -> stop : (unit -> unit Deferred.t) -> unit Deferred.t

  end

module Make 
    (State : sig type t [@@deriving eq] end)
    (Message : sig type t end)
    (Peer : sig type t end)
    (Timer : sig val wait : Time.Span.t -> unit Deferred.t end)
    (Condition_label : sig 
       type label [@@deriving enum]
       include Hashable.S with type t = label
     end)
    (Transport : Node.Transport_intf with type message := Message.t 
                                      and type peer := Peer.t) 
    (Node : Node.S with type message := Message.t
                    and type state := State.t
                    and module Condition_label := Condition_label)
= struct

    type t = 
      { nodes : Node.t list }

    type change = 
      | Delete of int
      | Add of Node.t

    type changes = State.t list -> change list

    let step t = failwith "nyi"

    let loop t ~stop = failwith "nyi"

end

