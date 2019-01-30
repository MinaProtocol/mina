open Async_kernel
open Core_kernel
open Pipe_lib
open Network_peer

exception Child_died

module Haskell : sig
  type t

  val connect :
       initial_peers:Host_and_port.t list
    -> me:Peer.t
    -> parent_log:Logger.t
    -> conf_dir:string
    -> banlist:Coda_base.Banlist.t
    -> t Deferred.Or_error.t

  val peers : t -> Peer.t list

  val first_peers : t -> Peer.t list Deferred.t

  val changes : t -> Peer.Event.t Linear_pipe.Reader.t

  val stop : t -> unit Deferred.t
end
