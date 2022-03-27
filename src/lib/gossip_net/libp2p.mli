type ('q, 'r) dispatch =
     Async.Versioned_rpc.Connection_with_menu.t
  -> 'q
  -> 'r Async.Deferred.Or_error.t

module Connection_with_state : sig
  type t = Banned | Allowed of Async.Rpc.Connection.t Async.Ivar.t

  val value_map :
       when_allowed:(Async.Rpc.Connection.t Async.Ivar.t -> 'a)
    -> when_banned:'a
    -> t
    -> 'a
end

module Config : sig
  type t =
    { timeout : Core.Time.Span.t
    ; initial_peers : Mina_net2.Multiaddr.t list
    ; addrs_and_ports : Node_addrs_and_ports.t
    ; metrics_port : int option
    ; conf_dir : string
    ; chain_id : string
    ; logger : Logger.t
    ; unsafe_no_trust_ip : bool
    ; isolate : bool
    ; trust_system : Trust_system.t
    ; flooding : bool
    ; direct_peers : Mina_net2.Multiaddr.t list
    ; peer_exchange : bool
    ; mina_peer_exchange : bool
    ; seed_peer_list_url : Uri.t option
    ; min_connections : int
    ; max_connections : int
    ; validation_queue_size : int
    ; mutable keypair : Mina_net2.Keypair.t option
    ; all_peers_seen_metric : bool
    ; known_private_ip_nets : Core.Unix.Cidr.t list
    }

  val make :
       timeout:Core.Time.Span.t
    -> ?initial_peers:Mina_net2.Multiaddr.t list
    -> addrs_and_ports:Node_addrs_and_ports.t
    -> ?metrics_port:int
    -> conf_dir:string
    -> chain_id:string
    -> logger:Logger.t
    -> unsafe_no_trust_ip:bool
    -> isolate:bool
    -> trust_system:Trust_system.t
    -> flooding:bool
    -> ?direct_peers:Mina_net2.Multiaddr.t list
    -> peer_exchange:bool
    -> mina_peer_exchange:bool
    -> ?seed_peer_list_url:Uri.t
    -> min_connections:int
    -> max_connections:int
    -> validation_queue_size:int
    -> ?keypair:Mina_net2.Keypair.t
    -> all_peers_seen_metric:bool
    -> ?known_private_ip_nets:Core.Unix.Cidr.t list
    -> unit
    -> t
end

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

  val create :
       Config.t
    -> pids:Child_processes.Termination.t
    -> Rpc_intf.rpc_handler list
    -> t Async.Deferred.t
end

val rpc_transport_proto : string

val download_seed_peer_list :
  Uri.t -> Mina_net2.Multiaddr.t list Async_kernel__Deferred.t

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

  val create :
       Config.t
    -> pids:Child_processes.Termination.t
    -> Rpc_intf.rpc_handler list
    -> t Async.Deferred.t
end
