open Async
open Core
open Stdint
open Pipe_lib
open Network_peer

include module type of Ipc

module Rpcs : module type of Rpcs

module Build : module type of Build

exception Received_undefined_union of string * int

module Sequence_number : sig
  type t = sequence_number

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val to_string : t -> string

  val create : unit -> t
end

module Subscription_id : sig
  type t = subscription_id

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  val to_string : t -> string

  val create : unit -> t
end

val undefined_union : context:string -> int -> unit

val unsafe_parse_peer_id : peer_id -> Peer.Id.t

val unsafe_parse_peer : peer_info -> Peer.t

val stream_id_to_string : stream_id -> string

val multiaddr_to_string : Reader.Multiaddr.t -> string

val unix_nano_to_time_span : Reader.UnixNano.t -> Time_ns.t

val create_multiaddr : string -> multiaddr

val create_peer_id : string -> Builder.PeerId.t

val create_libp2p_config :
     private_key:string
  -> statedir:string
  -> listen_on:multiaddr list
  -> ?metrics_port:int
  -> external_multiaddr:multiaddr
  -> network_id:string
  -> unsafe_no_trust_ip:bool
  -> flood:bool
  -> direct_peers:multiaddr list
  -> seed_peers:multiaddr list
  -> known_private_ip_nets:string list
  -> peer_exchange:bool
  -> peer_protection_ratio:float
  -> min_connections:int
  -> max_connections:int
  -> validation_queue_size:int
  -> gating_config:gating_config
  -> topic_config:string list list
  -> libp2p_config

val create_gating_config :
     banned_ips:string list
  -> banned_peers:Builder.PeerId.t list
  -> trusted_ips:string list
  -> trusted_peers:Builder.PeerId.t list
  -> isolate:bool
  -> gating_config

val create_rpc_request :
  sequence_number:sequence_number -> rpc_request_body -> rpc_request

val rpc_response_to_or_error : rpc_response -> rpc_response_body Or_error.t

val rpc_request_to_outgoing_message : rpc_request -> outgoing_message

val create_validation_push_message :
     validation_id:validation_id
  -> validation_result:validation_result
  -> push_message

val create_add_resource_push_message : tag:int -> data:string -> push_message

val push_message_to_outgoing_message : push_message -> outgoing_message

val read_incoming_messages :
     string Strict_pipe.Reader.t
  -> incoming_message Or_error.t Strict_pipe.Reader.t

val write_outgoing_message : Writer.t -> outgoing_message -> unit
