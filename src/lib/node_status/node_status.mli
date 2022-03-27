val get_node_status_from_peers :
     Mina_networking.t
  -> Mina_net2.Multiaddr.t list option
  -> Mina_networking.Rpcs.Get_node_status.Node_status.t Core_kernel.Or_error.t
     list
     Async_kernel__Deferred.t
