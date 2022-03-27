module type S = sig
  type t

  module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

  val restart_helper : t -> unit

  val peers : t -> Network_peer.Peer.t list Async.Deferred.t

  val bandwidth_info :
       t
    -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
       Async.Deferred.Or_error.t

  val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

  val get_peer_node_status :
    t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

  val initial_peers : t -> Mina_net2.Multiaddr.t list

  val add_peer :
    t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

  val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

  val set_connection_gating :
       t
    -> Mina_net2.connection_gating
    -> Mina_net2.connection_gating Async.Deferred.t

  val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

  val random_peers_except :
       t
    -> int
    -> except:Network_peer.Peer.Hash_set.t
    -> Network_peer.Peer.t list Async.Deferred.t

  val query_peer' :
       ?how:Async.Monad_sequence.how
    -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
    -> ?timeout:Core_kernel.Time.Span.t
    -> t
    -> Network_peer.Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q list
    -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

  val query_peer :
       ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
    -> ?timeout:Core_kernel.Time.Span.t
    -> t
    -> Network_peer.Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

  val query_random_peers :
       t
    -> int
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
       Async.Deferred.t

  val broadcast : t -> Message.msg -> unit

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

  val received_message_reader :
       t
    -> ( Message.msg Network_peer.Envelope.Incoming.t
       * Mina_net2.Validation_callback.t )
       Pipe_lib.Strict_pipe.Reader.t

  val ban_notification_reader :
    t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

  type network

  val create_network : Network_peer.Peer.t list -> network

  val create_instance :
       network
    -> Network_peer.Peer.t
    -> Rpc_intf.rpc_handler list
    -> t Async_kernel.Deferred.t
end

module Make : functor (Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf) -> sig
  type t

  val restart_helper : t -> unit

  val peers : t -> Network_peer.Peer.t list Async.Deferred.t

  val bandwidth_info :
       t
    -> ([ `Input of float ] * [ `Output of float ] * [ `Cpu_usage of float ])
       Async.Deferred.Or_error.t

  val set_node_status : t -> string -> unit Async.Deferred.Or_error.t

  val get_peer_node_status :
    t -> Network_peer.Peer.t -> string Async.Deferred.Or_error.t

  val initial_peers : t -> Mina_net2.Multiaddr.t list

  val add_peer :
    t -> Network_peer.Peer.t -> is_seed:bool -> unit Async.Deferred.Or_error.t

  val connection_gating : t -> Mina_net2.connection_gating Async.Deferred.t

  val set_connection_gating :
       t
    -> Mina_net2.connection_gating
    -> Mina_net2.connection_gating Async.Deferred.t

  val random_peers : t -> int -> Network_peer.Peer.t list Async.Deferred.t

  val random_peers_except :
       t
    -> int
    -> except:Network_peer.Peer.Hash_set.t
    -> Network_peer.Peer.t list Async.Deferred.t

  val query_peer' :
       ?how:Async.Monad_sequence.how
    -> ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
    -> ?timeout:Core_kernel.Time.Span.t
    -> t
    -> Network_peer.Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q list
    -> 'r list Mina_base.Rpc_intf.rpc_response Async.Deferred.t

  val query_peer :
       ?heartbeat_timeout:Core_kernel.Time_ns.Span.t
    -> ?timeout:Core_kernel.Time.Span.t
    -> t
    -> Network_peer.Peer.Id.t
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t

  val query_random_peers :
       t
    -> int
    -> ('q, 'r) Rpc_intf.rpc
    -> 'q
    -> 'r Mina_base.Rpc_intf.rpc_response Async.Deferred.t Core_kernel.List.t
       Async.Deferred.t

  val broadcast : t -> Message.msg -> unit

  val on_first_connect : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

  val on_first_high_connectivity : t -> f:(unit -> 'a) -> 'a Async.Deferred.t

  val received_message_reader :
       t
    -> ( Message.msg Network_peer.Envelope.Incoming.t
       * Mina_net2.Validation_callback.t )
       Pipe_lib.Strict_pipe.Reader.t

  val ban_notification_reader :
    t -> Intf.ban_notification Pipe_lib.Linear_pipe.Reader.t

  type network

  val create_network : Network_peer.Peer.t list -> network

  val create_instance :
       network
    -> Network_peer.Peer.t
    -> Rpc_intf.rpc_handler list
    -> t Async_kernel.Deferred.t
end
