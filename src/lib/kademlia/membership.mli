open Async_kernel
open Core
open Pipe_lib
open Network_peer

exception Child_died

module Haskell : sig
  type t

  val connect :
       initial_peers:Host_and_port.t list
    -> node_addrs_and_ports:Node_addrs_and_ports.t
    -> logger:Logger.t
    -> conf_dir:string
    -> trust_system:Trust_system.t
    -> t Deferred.Or_error.t

  val peers : t -> Peer.t list

  val first_peers : t -> Peer.t list Deferred.t

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit Deferred.t

  module Hacky_glue : sig
    val inject_event : t -> Peer.Event.t -> unit

    val forget_all : t -> unit
  end
end
