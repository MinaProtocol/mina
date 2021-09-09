open Async_kernel

module type S = sig
  module Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf

  module type Implementation_intf =
    Intf.Gossip_net_intf with module Rpc_intf := Rpc_intf

  type 't implementation = (module Implementation_intf with type t = 't)

  type t = Any : 't implementation * 't -> t

  include Intf.Gossip_net_intf with module Rpc_intf := Rpc_intf and type t := t

  type 't creator = Rpc_intf.rpc_handler list -> 't Deferred.t

  type creatable = Creatable : 't implementation * 't creator -> creatable

  val create : creatable -> t creator
end

module Make (Rpc_intf : Mina_base.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf = struct
  open Rpc_intf

  module type Implementation_intf =
    Intf.Gossip_net_intf with module Rpc_intf := Rpc_intf

  type 't implementation = (module Implementation_intf with type t = 't)

  type t = Any : 't implementation * 't -> t

  type 't creator = rpc_handler list -> 't Deferred.t

  type creatable = Creatable : 't implementation * 't creator -> creatable

  let create (Creatable ((module M), creator)) impls =
    let%map gossip_net = creator impls in
    Any ((module M), gossip_net)

  let peers (Any ((module M), t)) = M.peers t

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

  let ip_for_peer (Any ((module M), t)) = M.ip_for_peer t

  let broadcast (Any ((module M), t)) = M.broadcast t

  let on_first_connect (Any ((module M), t)) = M.on_first_connect t

  let on_first_high_connectivity (Any ((module M), t)) =
    M.on_first_high_connectivity t

  let received_message_reader (Any ((module M), t)) =
    M.received_message_reader t

  let ban_notification_reader (Any ((module M), t)) =
    M.ban_notification_reader t

  let connection_gating (Any ((module M), t)) = M.connection_gating t

  let set_connection_gating (Any ((module M), t)) config =
    M.set_connection_gating t config

  let restart_helper (Any ((module M), t)) = M.restart_helper t
end
