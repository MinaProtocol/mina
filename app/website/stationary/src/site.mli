open Async

(** This module allows you to construct a site. *)

(** A representation of your site. *)
type t

(** Create a site with the given filesystem. *)
val create : File_system.t list -> t

(** Build a site at the specified path. *)
val build : t -> dst:string -> unit Deferred.t
