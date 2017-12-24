open Async_kernel
open Core_kernel

module type S = sig
  type t

  val connect
    : initial_peers:Host_and_port.t list -> me:Host_and_port.t -> t Deferred.t

  val peers : t -> Host_and_port.t list

  val changes : t -> Peer.Event.t Pipe.Reader.t
end


(*module type S = sig*)
  (*type t*)

  (*val connect*)
    (*: initial_peers:Peer.t list -> t*)

  (*val peers : t -> Peer.t list*)

  (*val changes : t -> Peer.Event.t Pipe.Reader.t*)
(*end*)

module Udp : S
