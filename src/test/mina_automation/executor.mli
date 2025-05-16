(* executor.mli *)
open Async

(** The type representing an executor *)


module type AppPaths = sig
  (** The path to app from repo root *)
  val dune_name : string
 
  (** The name of an app after debian/docker installation*)
  val official_name : string
end

(** Module DockerContext provides an abstract type [t] representing the context for Docker operations. *)
module DockerContext : sig
  type t
end

(** 
  This module provides a functor [Make_PathFinder] that takes a module of type [AppPaths] 
  and returns a module with the following components:

*)
module Make_PathFinder (P : AppPaths) : sig
  module Paths : AppPaths

  (** [standalone_path] Path to the executable after installation (outside dune context)
    It returns [Some path] if the path is available, otherwise [None]. *)
  val standalone_path : string option Deferred.t

  (** [standalone_path_exn] Path to the executable after installation (outside dune context)
    It raises an exception if the path is not available. *)
  val standalone_path_exn : string Deferred.t
end

module Make (P : AppPaths) : sig
  type t =
    | Dune (* application ran from dune exec command *)
    | Local (* application ran from _build/default folder*)
    | Debian (* application installed from mina debian package *)
    | Docker of DockerContext.t (* application ran from docker container *)
    | AutoDetect (* automatically detect the context *)

  module PathFinder : sig
    module Paths : AppPaths

    val standalone_path : string option Deferred.t

    val standalone_path_exn : string Deferred.t
  end

  val default : t

  val run :
       t
    -> args:string list
    -> ?env:Core.Unix.env
    -> ?ignore_failure:bool
    -> unit
    -> string Deferred.t

  val run_in_background :
    t -> args:string list -> ?env:Core.Unix.env -> unit -> Process.t Deferred.t
end
