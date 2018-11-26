(** In the current workspace (anything under the current project root) *)
module Local : sig
  type t
  val to_sexp : t -> Sexp.t
  val equal : t -> t -> bool
  val to_string : t -> string
end

(** In the outside world *)
module External : sig
  type t

  val to_string : t -> string
  val of_string : string -> t
  val initial_cwd : t

  val cwd : unit -> t
end

module Kind : sig
  type t = private
    | External of External.t
    | Local    of Local.t

  val of_string : string -> t
end

type t

val to_sexp : t Sexp.Encoder.t

val compare : t -> t -> Ordering.t
(** a directory is smaller than its descendants *)

val equal : t -> t -> bool

module Set : sig
  include Set.S with type elt = t
  val to_sexp : t Sexp.Encoder.t
  val of_string_set : String.Set.t -> f:(string -> elt) -> t
end

module Map : Map.S with type key = t
module Table : Hashtbl.S with type key = t

val of_string : ?error_loc:Loc.t -> string -> t
val to_string : t -> string

(** [to_string_maybe_quoted t] is [maybe_quoted (to_string t)] *)
val to_string_maybe_quoted : t -> string

val kind : t -> Kind.t

val root : t
val is_root : t -> bool

val is_managed : t -> bool

val relative : ?error_loc:Loc.t -> t -> string -> t

(** Create an external path. If the argument is relative, assume it is relative
    to the initial directory dune was launched in. *)
val of_filename_relative_to_initial_cwd : string -> t

(** Convert a path to an absolute filename. Must be called after the workspace
    root has been set. [root] is the root directory of local paths *)
val to_absolute_filename : t -> string

val reach : t -> from:t -> string

(** [from] defaults to [Path.root] *)
val reach_for_running : ?from:t -> t -> string

val descendant : t -> of_:t -> t option
val is_descendant : t -> of_:t -> bool

val append : t -> t -> t
val append_local : t -> Local.t -> t

val basename : t -> string
val parent : t -> t option
val parent_exn : t -> t

val is_suffix : t -> suffix:string -> bool

val extend_basename : t -> suffix:string -> t

(** Extract the build context from a path. For instance, representing paths as strings:

    {[
      extract_build_context "_build/blah/foo/bar" = Some ("blah", "foo/bar")
    ]}
*)
val extract_build_context : t -> (string * t) option

(** Same as [extract_build_context] but return the build context as a path:

    {[
      extract_build_context "_build/blah/foo/bar" = Some ("_build/blah", "foo/bar")
    ]}
*)
val extract_build_context_dir : t -> (t * t) option

(** Drop the "_build/blah" prefix *)
val drop_build_context : t -> t option
val drop_build_context_exn : t -> t

(** Drop the "_build/blah" prefix if present, return [t] otherwise *)
val drop_optional_build_context : t -> t

(** Transform managed paths so that they are descedant of
    [sandbox_dir]. *)
val sandbox_managed_paths : sandbox_dir:t -> t -> t

val explode : t -> string list option
val explode_exn : t -> string list

(** The build directory *)
val build_dir : t

(** [is_in_build_dir t = is_descendant t ~of:build_dir] *)
val is_in_build_dir : t -> bool

(** [is_in_build_dir t = is_managed t && not (is_in_build_dir t)] *)
val is_in_source_tree : t -> bool

val is_alias_stamp_file : t -> bool

(** [is_strict_descendant_of_build_dir t = is_in_build_dir t && t <>
    build_dir] *)
val is_strict_descendant_of_build_dir : t -> bool

(**  Split after the first component if [t] is local *)
val split_first_component : t -> (string * t) option

val insert_after_build_dir_exn : t -> string -> t

val exists : t -> bool
val readdir_unsorted : t -> string list
val is_directory : t -> bool
val rmdir : t -> unit
val unlink : t -> unit
val unlink_no_err : t -> unit
val rm_rf : t -> unit
val mkdir_p : t -> unit

val extension : t -> string
val split_extension : t -> t * string

val pp : Format.formatter -> t -> unit
val pp_debug : Format.formatter -> t -> unit

val build_dir_exists : unit -> bool

val ensure_build_dir_exists : unit -> unit

(** set the build directory. Can only be called once and must be done before
    paths are converted to strings elsewhere. *)
val set_build_dir : Kind.t -> unit

(** paths guaranteed to be in the source directory *)
val in_source : string -> t

val of_local : Local.t -> t

(** Set the workspace root. Can onyl be called once and the path must be
    absolute *)
val set_root : External.t -> unit

(** Internal use only *)
module Internal : sig
  val raw_kind : t -> Kind.t
end

module L : sig
  val relative : t -> string list -> t
end

(** Return the "local part" of a path.
    For local paths (in build directory or source tree),
    this returns the path itself.
    For external paths, it returns a path that is relative to the current
    directory. For example, the local part of [/a/b] is [./a/b]. *)
val local_part : t -> Local.t
