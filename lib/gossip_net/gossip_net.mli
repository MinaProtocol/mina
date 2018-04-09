open Core
open Async
open Kademlia

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module type Message_intf = sig
  type msg
  include Versioned_rpc.Both_convert.One_way.S
    with type callee_msg := msg
    and type caller_msg := msg
end

module type S =
  functor (Message : Message_intf) -> sig

    type t = 
      { timeout : Time.Span.t
      ; log : Logger.t
      ; target_peer_count : int
      ; new_peer_reader : Peer.t Linear_pipe.Reader.t
      ; broadcast_writer : Message.msg Linear_pipe.Writer.t
      ; received_reader : Message.msg Linear_pipe.Reader.t
      ; peers : Peer.Hash_set.t
      }

    module Params : sig
      type t =
        { timeout           : Time.Span.t
        ; target_peer_count : int
        ; address           : Peer.t
        }
    end

    val create
      :  Peer.Event.t Linear_pipe.Reader.t
      -> Params.t
      -> Logger.t
      -> unit Rpc.Implementation.t list
      -> t

    val received : t -> Message.msg Linear_pipe.Reader.t

    val broadcast : t -> Message.msg Linear_pipe.Writer.t

    val broadcast_all : t -> Message.msg -> 
      (unit -> [`Done | `Continue] Deferred.t) Staged.t

    val query_peer
      : t
      -> Peer.t
      -> ('q, 'r) dispatch
      -> 'q
      -> 'r Or_error.t Deferred.t

    val query_random_peers
      : t
      -> int
      -> ('q, 'r) dispatch
      -> 'q
      -> 'r Or_error.t Deferred.t List.t
  end

module Make : S
