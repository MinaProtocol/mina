open! Stdune
(** Dune representation of the source tree *)

open! Import

module Dune_file : sig
  module Plain : sig
    (** [sexps] is mutable as we get rid of the S-expressions once
        they have been parsed, in order to release the memory as soon
        as we don't need them. *)
    type t =
      { path          : Path.t
      ; mutable sexps : Dune_lang.Ast.t list
      }
  end

  module Contents : sig
    type t = private
      | Plain of Plain.t
      | Ocaml_script of Path.t
  end

  type t = private
    { contents : Contents.t
    ; kind     : Dune_lang.Syntax.t
    }

  val path : t -> Path.t
end

module Dir : sig
  type t

  val path     : t -> Path.t
  val files    : t -> String.Set.t
  val file_paths    : t -> Path.Set.t
  val sub_dirs : t -> t String.Map.t
  val sub_dir_paths : t -> Path.Set.t
  val sub_dir_names : t -> String.Set.t

  (** Whether this directory is ignored by an [ignored_subdirs] stanza
     or [jbuild-ignore] file in one of its ancestor directories. *)
  val ignored : t -> bool

  val fold
    :  t
    -> traverse_ignored_dirs:bool
    -> init:'a
    -> f:(t -> 'a -> 'a)
    -> 'a

  (** Return the contents of the dune (or jbuild) file in this directory *)
  val dune_file : t -> Dune_file.t option

  (** Return the project this directory is part of *)
  val project : t -> Dune_project.t
end

(** A [t] value represent a view of the source tree. It is lazily
    constructed by scanning the file system and interpreting [.dune-fs]
    files, as well as [jbuild-ignore] files for backward
    compatibility. *)
type t

val load : ?extra_ignored_subtrees:Path.Set.t -> Path.t -> t

(** Passing [~traverse_ignored_dirs:true] to this functions causes the
    whole source tree to be deeply scanned, including ignored
    sub-trees. *)
val fold
  :  t
  -> traverse_ignored_dirs:bool
  -> init:'a
  -> f:(Dir.t -> 'a -> 'a)
  -> 'a

val root : t -> Dir.t

val find_dir : t -> Path.t -> Dir.t option

val files_of : t -> Path.t -> Path.Set.t

(** [true] iff the path is either a directory or a file *)
val exists : t -> Path.t -> bool

(** [true] iff the path is a directory *)
val dir_exists : t -> Path.t -> bool

(** [true] iff the path is a file *)
val file_exists : t -> Path.t -> string -> bool

val files_recursively_in : t -> ?prefix_with:Path.t -> Path.t -> Path.Set.t
