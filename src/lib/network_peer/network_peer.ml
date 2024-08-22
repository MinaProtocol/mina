open Async_kernel
open Async_rpc_kernel
module Peer = Peer
module Envelope = Envelope

(* TODO: move this out of Network_peer *)
type query_peer =
  { query :
      'r 'q.
         Peer.t
      -> (Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t)
      -> 'q
      -> 'r Deferred.Or_error.t
  }
