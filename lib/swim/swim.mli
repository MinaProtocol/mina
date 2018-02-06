open Async_kernel
open Core_kernel

module Config : sig
  type t

  val create : ?indirect_ping_count:int
    -> ?expected_latency:Time.Span.t
    -> unit
    -> t

  val indirect_ping_count : t -> int
  val protocol_period : t -> Time.Span.t
  val round_trip_time : t -> Time.Span.t
end

module type S = sig
  type t

  val connect
    : config:Config.t -> initial_peers:Peer.t list -> me:Peer.t -> t

  val peers : t -> Peer.t list

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit

  module TestOnly : sig
    val network_partition_add : from:Peer.t -> to_:Peer.t -> unit
    val network_partition_remove : from:Peer.t -> to_:Peer.t -> unit
  end
end


module Udp : S
module Test : S

