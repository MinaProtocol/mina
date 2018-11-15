open Stdune

module L : sig

  (** [file_deps t libs ~ext] returns a list of path dependencies for all the
      files with extension [ext] of libraries [libs]. *)
  val file_deps : Super_context.t -> Lib.L.t -> exts:string list -> Path.t list

  val file_deps_with_exts
    :  Super_context.t
    -> (Lib.t * string list) list
    -> Path.t list
end

(** Setup the alias that depends on all files with a given extension for a
    library *)
val setup_file_deps_alias
  :  Super_context.t
  -> dir:Path.t
  -> exts:string list
  -> Dune_file.Library.t
  -> Path.Set.t
  -> unit

(** Setup an alias that depend on all files with the given extensions.*)
val setup_file_deps_group_alias
  :  Super_context.t
  -> dir:Path.t
  -> exts:string list
  -> Dune_file.Library.t
  -> unit
