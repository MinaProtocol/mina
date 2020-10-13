open Async_kernel

module type S = sig
  module Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf

  module type Implementation_intf =
    Intf.Gossip_net_intf with module Rpc_intf := Rpc_intf

  type 't implementation = (module Implementation_intf with type t = 't)

  type t = Any : 't implementation * 't -> t

  include Intf.Gossip_net_intf with module Rpc_intf := Rpc_intf and type t := t

  type 't creator = Rpc_intf.rpc_handler list -> 't Deferred.t

  type creatable = Creatable : 't implementation * 't creator -> creatable

  val create : creatable -> t creator
end

module Make (Rpc_intf : Coda_base.Rpc_intf.Rpc_interface_intf) :
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

  let initial_peers (Any ((module M), t)) = M.initial_peers t

  let random_peers (Any ((module M), t)) = M.random_peers t

  let random_peers_except (Any ((module M), t)) = M.random_peers_except t

  let query_peer (Any ((module M), t)) = M.query_peer t

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
end
