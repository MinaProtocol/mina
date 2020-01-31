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

  val peers : t -> Peer.t list

  val initial_peers : t -> Host_and_port.t list

  val peers_by_ip : t -> Unix.Inet_addr.t -> Peer.t list

  val random_peers : t -> int -> Peer.t list

  val random_peers_except : t -> int -> except:Peer.Hash_set.t -> Peer.t list

  val query_peer :
    t -> Peer.t -> ('q, 'r) Rpc_intf.rpc -> 'q -> 'r Or_error.t Deferred.t

  val query_random_peers :
    t -> int -> ('q, 'r) Rpc_intf.rpc -> 'q -> 'r Or_error.t Deferred.t List.t

  val broadcast : t -> Message.msg -> unit

  val broadcast_all :
    t -> Message.msg -> (unit -> [`Done | `Continue] Deferred.t) Staged.t

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

  val received_message_reader :
    t -> Message.msg Envelope.Incoming.t Strict_pipe.Reader.t

  val ban_notification_reader : t -> ban_notification Linear_pipe.Reader.t

  val net2 : t -> Coda_net2.net option
end
