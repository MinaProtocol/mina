open Async_kernel

module type S = sig
  val connect
    : initial_peers:Peer.t list -> Peer.Event.t Pipe.Reader.t
end

module Udp : S
