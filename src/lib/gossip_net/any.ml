open Async_kernel
open Intf

module type S = sig
  module Rpc_interface : RPC_INTERFACE

  module type IMPLEMENTATION =
    GOSSIP_NET with module Rpc_interface := Rpc_interface

  type 't implementation = (module IMPLEMENTATION with type t = 't)

  type t = Any : 't implementation * 't -> t

  include IMPLEMENTATION with type t := t

  type 't creator = Rpc_interface.ctx -> Message.sinks -> 't Deferred.t

  type creatable = Creatable : 't implementation * 't creator -> creatable

  val create : creatable -> t creator
end

module Make (Rpc_interface : RPC_INTERFACE) :
  S with module Rpc_interface := Rpc_interface = struct
  module type IMPLEMENTATION =
    GOSSIP_NET with module Rpc_interface := Rpc_interface

  type 't implementation = (module IMPLEMENTATION with type t = 't)

  type t = Any : 't implementation * 't -> t

  type 't creator = Rpc_interface.ctx -> Message.sinks -> 't Deferred.t

  type creatable = Creatable : 't implementation * 't creator -> creatable

  let create (Creatable ((module M), creator)) ctx sinks =
    let%map gossip_net = creator ctx sinks in
    Any ((module M), gossip_net)

  let peers (Any ((module M), t)) = M.peers t

  let bandwidth_info (Any ((module M), t)) = M.bandwidth_info t

  let set_node_status (Any ((module M), t)) = M.set_node_status t

  let get_peer_node_status (Any ((module M), t)) = M.get_peer_node_status t

  let add_peer (Any ((module M), t)) xs = M.add_peer t xs

  let initial_peers (Any ((module M), t)) = M.initial_peers t

  let random_peers (Any ((module M), t)) = M.random_peers t

  let random_peers_except (Any ((module M), t)) = M.random_peers_except t

  let query_peer ?heartbeat_timeout ?timeout (Any ((module M), t)) =
    M.query_peer ?heartbeat_timeout ?timeout t

  let query_peer' ?how ?heartbeat_timeout ?timeout (Any ((module M), t)) =
    M.query_peer' ?how ?heartbeat_timeout ?timeout t

  let query_random_peers (Any ((module M), t)) = M.query_random_peers t

  let broadcast_state ?origin_topic (Any ((module M), t)) =
    M.broadcast_state ?origin_topic t

  let broadcast_transaction_pool_diff ?origin_topic ?nonce (Any ((module M), t))
      =
    M.broadcast_transaction_pool_diff ?origin_topic ?nonce t

  let broadcast_snark_pool_diff ?origin_topic ?nonce (Any ((module M), t)) =
    M.broadcast_snark_pool_diff ?origin_topic ?nonce t

  let on_first_connect (Any ((module M), t)) = M.on_first_connect t

  let on_first_high_connectivity (Any ((module M), t)) =
    M.on_first_high_connectivity t

  let ban_notification_reader (Any ((module M), t)) =
    M.ban_notification_reader t

  let connection_gating (Any ((module M), t)) = M.connection_gating t

  let set_connection_gating ?clean_added_peers (Any ((module M), t)) config =
    M.set_connection_gating ?clean_added_peers t config

  let restart_helper (Any ((module M), t)) = M.restart_helper t
end
