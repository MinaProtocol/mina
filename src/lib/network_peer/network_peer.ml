module Peer = Peer
module Envelope = Envelope
module Rpc_intf = Rpc_intf

type query_peer =
  { query :
      'r 'q.    Peer.t
      -> (   Async_rpc_kernel.Versioned_rpc.Connection_with_menu.t
          -> 'q
          -> 'r Async_kernel.Deferred.Or_error.t) -> 'q
      -> 'r Async_kernel.Deferred.Or_error.t
  }
