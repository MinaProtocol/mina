open Async
open Core_kernel
open Network_peer
open Pipe_lib
open Coda_base.Rpc_intf

type ban_creator = {banned_peer: Peer.t; banned_until: Time.t}
[@@deriving fields]

type ban_notification = {banned_peer: Peer.t; banned_until: Time.t}

module type Gossip_net_intf = sig
  type t

  module Rpc_intf : Rpc_interface_intf

  val peers : t -> Peer.t list Deferred.t

  val initial_peers : t -> Coda_net2.Multiaddr.t list

  val connection_gating : t -> Coda_net2.connection_gating Deferred.t

  val set_connection_gating :
    t -> Coda_net2.connection_gating -> unit Deferred.t

  val random_peers : t -> int -> Peer.t list Deferred.t

  val random_peers_except :
    t -> int -> except:Peer.Hash_set.t -> Peer.t list Deferred.t

  val query_peer :
    t -> Peer.Id.t -> ('q, 'r) Rpc_intf.rpc -> 'q -> 'r rpc_response Deferred.t

  val query_random_peers :
       t
    -> int
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r rpc_response Deferred.t List.t Deferred.t

  val ip_for_peer : t -> Peer.Id.t -> Peer.t option Deferred.t

  val broadcast : t -> Message.msg -> unit

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

  val received_message_reader :
       t
    -> (Message.msg Envelope.Incoming.t * (bool -> unit)) Strict_pipe.Reader.t

  val ban_notification_reader : t -> ban_notification Linear_pipe.Reader.t
end
