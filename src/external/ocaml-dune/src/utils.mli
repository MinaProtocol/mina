(** Utilities that can't go in [Import] *)

open! Stdune

(** Return the absolute path to the shell and the argument to pass it
    (-c or /c). Raise in case in cannot be found. *)
val system_shell_exn : needed_to:string -> Path.t * string

(** Same as [system_shell_exn] but for bash *)
val bash_exn : needed_to:string -> Path.t

(** Convert a signal number to a name: INT, TERM, ... *)
val signal_name : int -> string

(** Nice description of a target *)
val describe_target : Path.t -> string

(** Return the directory where the object files for the given
    library should be stored. *)
val library_object_directory
  :  dir:Path.t
  -> Lib_name.Local.t
  -> Path.t

val library_private_obj_dir : obj_dir:Path.t -> Path.t

(** Return the directory where the object files for the given
    executable should be stored. *)
val executable_object_directory
  :  dir:Path.t
  -> string
  -> Path.t

type target_kind =
  | Regular of string (* build context *) * Path.t
  | Alias   of string (* build context *) * Path.t
  | Other of Path.t

(** Return the name of an alias from its stamp file *)
val analyse_target : Path.t -> target_kind

(** Raise an error about a program not found in the PATH or in the tree *)
val program_not_found
  :  ?context:string
  -> ?hint:string
  -> loc:Loc.t option
  -> string
  -> _

(** Raise an error about a library not found *)
val library_not_found : ?context:string -> ?hint:string -> string -> _

val install_file
  :  package:Package.Name.t
  -> findlib_toolchain:string option
  -> string

(** Produce a line directive *)
val line_directive : filename:string -> line_number:int -> string

(** [local_bin dir] The directory which contains the local binaries viewed by
    rules defined in [dir] *)
val local_bin : Path.t -> Path.t

module type Persistent_desc = sig
  type t
  val name : string
  val version : int
end

(** Persistent value stored on disk *)
module Persistent(D : Persistent_desc) : sig
  val to_out_string : D.t -> string
  val dump : Path.t -> D.t -> unit
  val load : Path.t -> D.t option
end

(** Digest files with caching *)
module Cached_digest : sig
  (** Digest the contents of the following file *)
  val file : Path.t -> Digest.t

  (** Clear the following digest from the cache *)
  val remove : Path.t -> unit

  (** Same as {!file} but forces the digest to be recomputed *)
  val refresh : Path.t -> Digest.t

  (** Dump/load the cache to/from the disk *)
  val dump : unit -> unit
  val load : unit -> unit
end
