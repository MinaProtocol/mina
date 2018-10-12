open Async

(** This module provides a type which represents a specification of
    the filesystem that is your site. *)

(** A specification of a filesystem. *)
type t

(** Declare a file to be in the filesystem. *)
val file : File.t -> t

(** Declare a directory with the given name and children. *)
val directory : string -> t list -> t

(** Specify that the given directory ought to be copied into the filesystem
    of your site. *)
val copy_directory : ?name:string -> string -> t

(** Specify that the given directory ought to be symlinked into the filesystem
    of your site. *)
val symlink_directory : ?name:string -> string -> t

(** Build the specification at a given path. *)
val build : t -> dst:string -> unit Deferred.t
