open Async
open Core_kernel
open Network_peer
open Pipe_lib

type ban_creator = { banned_peer : Peer.t; banned_until : Time.t }
[@@deriving fields]

type ban_notification = { banned_peer : Peer.t; banned_until : Time.t }

(* error types for specific rpc calls *)
type rpc_error =
  (* failure to perform rpc call (version negotiation, conversion/encoding errors) *)
  | Rpc_call_error of Error.t
  (* successfully performed rpc call, but the server responded with an error *)
  | Rpc_returned_error of Error.t

type 'r rpc_response = ('r, rpc_error) Result.t

type 'r connection_result =
  | Failed_to_connect of Error.t
  | Internal_exception of exn
  | Connected of 'r Envelope.Incoming.t

module type RPC_IMPLEMENTATION = sig
  type ctx

  type query

  type reply

  type response = reply Or_error.t

  val name : string

  val versions : unit -> Int.Set.t

  val sent_counter : Mina_metrics.Counter.t * Mina_metrics.Gauge.t

  val received_counter : Mina_metrics.Counter.t * Mina_metrics.Gauge.t

  val failed_request_counter : Mina_metrics.Counter.t

  val failed_response_counter : Mina_metrics.Counter.t

  val implement_multi :
       ?log_not_previously_seen_version:(name:string -> int -> unit)
    -> (Peer.t -> version:int -> query -> response Deferred.t)
    -> Peer.t Rpc.Implementation.t list

  val dispatch_multi :
       Versioned_rpc.Connection_with_menu.t
    -> query
    -> response Deferred.Or_error.t

  val log_request_received : logger:Logger.t -> sender:Peer.t -> query -> unit

  val receipt_trust_action_message :
    query -> string * (string, Yojson.Safe.t) List.Assoc.t

  val handle_request :
    ctx -> version:int -> query Envelope.Incoming.t -> response Deferred.t

  val rate_limit_cost : query -> int

  val rate_limit_budget : int * [ `Per of Time.Span.t ]
end

type ('ctx, 'query, 'reply) rpc_implementation =
  (module RPC_IMPLEMENTATION
     with type ctx = 'ctx
      and type query = 'query
      and type reply = 'reply )

module type RPC_INTERFACE = sig
  type ctx

  type ('query, 'reply) rpc

  type any_rpc = Rpc : ('query, 'reply) rpc -> any_rpc

  val all_rpcs : any_rpc list

  val implementation :
    ('query, 'reply) rpc -> (ctx, 'query, 'reply) rpc_implementation
end

module type GOSSIP_NET = sig
  type t

  module Rpc_interface : RPC_INTERFACE

  val restart_helper : t -> unit

  val peers : t -> Peer.t list Deferred.t

  val bandwidth_info :
       t
    -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
       Deferred.Or_error.t

  val set_node_status : t -> string -> unit Deferred.Or_error.t

  val get_peer_node_status : t -> Peer.t -> string Deferred.Or_error.t

  val initial_peers : t -> Mina_net2.Multiaddr.t list

  val add_peer : t -> Peer.t -> is_seed:bool -> unit Deferred.Or_error.t

  val connection_gating : t -> Mina_net2.connection_gating Deferred.t

  val set_connection_gating :
       ?clean_added_peers:bool
    -> t
    -> Mina_net2.connection_gating
    -> Mina_net2.connection_gating Deferred.t

  val random_peers : t -> int -> Peer.t list Deferred.t

  val random_peers_except :
    t -> int -> except:Peer.Hash_set.t -> Peer.t list Deferred.t

  val query_peer' :
       ?how:Monad_sequence.how
    -> ?heartbeat_timeout:Time_ns.Span.t
    -> ?timeout:Time.Span.t
    -> t
    -> Peer.t
    -> ('q, 'r) Rpc_interface.rpc
    -> 'q list
    -> 'r rpc_response list connection_result Deferred.t

  val query_peer :
       ?heartbeat_timeout:Time_ns.Span.t
    -> ?timeout:Time.Span.t
    -> t
    -> Peer.t
    -> ('q, 'r) Rpc_interface.rpc
    -> 'q
    -> 'r rpc_response connection_result Deferred.t

  val query_random_peers :
       t
    -> int
    -> ('q, 'r) Rpc_interface.rpc
    -> 'q
    -> 'r rpc_response connection_result Deferred.t list Deferred.t

  val broadcast_state :
    ?origin_topic:string -> t -> Message.state_msg -> unit Deferred.t

  val broadcast_transaction_pool_diff :
       ?origin_topic:string
    -> ?nonce:int
    -> t
    -> Message.transaction_pool_diff_msg
    -> unit Deferred.t

  val broadcast_snark_pool_diff :
       ?origin_topic:string
    -> ?nonce:int
    -> t
    -> Message.snark_pool_diff_msg
    -> unit Deferred.t

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Deferred.t

  val ban_notification_reader : t -> ban_notification Linear_pipe.Reader.t
end
