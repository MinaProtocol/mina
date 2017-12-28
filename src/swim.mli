open Async_kernel
open Core_kernel

module type S = sig
  type t

  module Config : sig
    type t

    val create : ?indirect_ping_count:int
      -> ?expected_latency:Time.Span.t
      -> unit
      -> t

    val indirect_ping_count : t -> int
    val protocol_period : t -> Time.Span.t
    val rtt : t -> Time.Span.t
  end

  val connect
    : config:Config.t -> initial_peers:Host_and_port.t list -> me:Host_and_port.t -> t Deferred.t

  val peers : t -> Host_and_port.t list

  val changes : t -> Peer.Event.t Pipe.Reader.t

  val stop : t -> unit

  (* TODO: This is kinda leaky *)
  val test_only_network_partition_add : from:Host_and_port.t -> to_:Host_and_port.t -> unit
  val test_only_network_partition_remove : from:Host_and_port.t -> to_:Host_and_port.t -> unit
end


module Udp : S
module Test : S
