open Core_kernel
open Async_kernel

(** The interface to some peer-to-peer storage system. *)
module type Store_intf = sig
  (** Information that lets us locate some data. *)
  module Handle : sig
    type t [@@deriving bin_io]
  end

  module Session : sig
    type t

    module Config : sig
      type t = {path: string; port: int option; datadir: string}
      [@@deriving_make]
    end

    val create : Config.t -> t Deferred.Or_error.t
  end

  val offer : Session.t -> string -> Handle.t Deferred.Or_error.t
  (** Make some data available. Returns a handle which can be sent to other
      nodes. Those nodes can hopefully use the handle to fetch the data
      from the network. *)

  val retrieve : Session.t -> Handle.t -> string Deferred.Or_error.t
  (** Retrieve some data from the network.

      This will probably take a while. There's no support for progress
      notifications yet. If it fails, maybe just try again? *)

  val forget : Session.t -> Handle.t -> unit
  (** Stop offering some data. This will free up disk space. *)
end

module Bittorrent : Store_intf = Bittorrent
