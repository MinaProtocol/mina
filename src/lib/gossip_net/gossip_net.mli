open Core
open Async
open Coda_base
open Pipe_lib
open Network_peer

module Message : sig
  type content

  type msg

  include
    Versioned_rpc.Both_convert.One_way.S
    with type callee_msg := msg
     and type caller_msg := msg

  val content : msg -> content

  val sender : msg -> Envelope.Sender.t
end

type content

type msg

type t =
  { timeout: Block_time.Span.t
  ; logger: Logger.t
  ; target_peer_count: int
  ; broadcast_writer: msg Linear_pipe.Writer.t
  ; received_reader: content Envelope.Incoming.t Strict_pipe.Reader.t
  ; me: Peer.t
  ; peers: Peer.Hash_set.t
  ; connections: (Unix.Inet_addr.t, Rpc.Connection.t) Hashtbl.t }

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module type Config_intf = sig
  type t =
    { timeout: Block_time.Span.t
    ; target_peer_count: int
    ; initial_peers: Host_and_port.t list
    ; me: Peer.t
    ; conf_dir: string
    ; logger: Logger.t
    ; trust_system: Coda_base.Trust_system.t }
  [@@deriving make]
end

module Config : Config_intf

val create :
  Config.t -> Host_and_port.t Rpc.Implementation.t list -> t Deferred.t

val received : t -> content Envelope.Incoming.t Strict_pipe.Reader.t

val broadcast : t -> msg Linear_pipe.Writer.t

val broadcast_all :
  t -> msg -> (unit -> [`Done | `Continue] Deferred.t) Staged.t

val random_peers : t -> int -> Peer.t list

val random_peers_except : t -> int -> except:Peer.Hash_set.t -> Peer.t list

val peers : t -> Peer.t list

val query_peer :
  t -> Peer.t -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t

val query_random_peers :
  t -> int -> ('q, 'r) dispatch -> 'q -> 'r Or_error.t Deferred.t List.t
