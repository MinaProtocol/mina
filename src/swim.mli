open Async_kernel

module type S = sig
  type t

  val connect
    : initial_peers:Peer.t list -> t

  val peers : t -> Peer.t list

  val changes : t -> Peer.Event.t Pipe.Reader.t
end

module Udp : S
