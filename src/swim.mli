open Async_kernel
open Core_kernel

module type S = sig
  type t
  type config =
    { indirect_ping_count : int
    ; protocol_period : Time.Span.t
    ; rtt : Time.Span.t
    }

  val connect
    : ?config:config -> initial_peers:Host_and_port.t list -> me:Host_and_port.t -> t Deferred.t

  val peers : t -> Host_and_port.t list

  val changes : t -> Peer.Event.t Pipe.Reader.t

  val stop : t -> unit

  (* TODO: This is kinda leaky *)
  val test_only_network_partition_add : from:Host_and_port.t -> to_:Host_and_port.t -> unit
  val test_only_network_partition_remove : from:Host_and_port.t -> to_:Host_and_port.t -> unit
end


(*module type S = sig*)
  (*type t*)

  (*val connect*)
    (*: initial_peers:Peer.t list -> t*)

  (*val peers : t -> Peer.t list*)

  (*val changes : t -> Peer.Event.t Pipe.Reader.t*)
(*end*)

module Udp : S
module Test : S
