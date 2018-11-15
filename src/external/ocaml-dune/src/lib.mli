open! Stdune
open Import

(** {1 Generals} *)

(** Representation of a library *)
type t

(** For libraries defined in the workspace, this is the [public_name] if
    present or the [name] if not. *)
val name : t -> Lib_name.t

(* CR-someday diml: this should be [Path.t list], since some libraries
   have multiple source directories because of [copy_files]. *)
(** Directory where the source files for the library are located. *)
val src_dir : t -> Path.t

(** Directory where the object files for the library are located. *)
val obj_dir : t -> Path.t

val private_obj_dir : t -> Path.t option

(** Same as [Path.is_managed (obj_dir t)] *)
val is_local : t -> bool

val synopsis     : t -> string option
val kind         : t -> Dune_file.Library.Kind.t
val archives     : t -> Path.t list Mode.Dict.t
val plugins      : t -> Path.t list Mode.Dict.t
val jsoo_runtime : t -> Path.t list
val jsoo_archive : t -> Path.t option

val foreign_objects : t -> Path.t list

val main_module_name : t -> Module.Name.t option Or_exn.t

val virtual_ : t -> Lib_info.Virtual.t option

val dune_version : t -> Syntax.Version.t option

(** A unique integer identifier. It is only unique for the duration of
    the process *)
val unique_id : t -> int

module Set : Set.S with type elt = t

module Map : Map.S with type key = t

val status : t -> Lib_info.Status.t

val package : t -> Package.Name.t option

(** Operations on list of libraries *)
module L : sig
  type nonrec t = t list

  val include_paths : t -> stdlib_dir:Path.t -> Path.Set.t
  val include_flags : t -> stdlib_dir:Path.t -> _ Arg_spec.t

  val c_include_flags : t -> stdlib_dir:Path.t -> _ Arg_spec.t

  val link_flags : t -> mode:Mode.t -> stdlib_dir:Path.t -> _ Arg_spec.t

  val compile_and_link_flags
    :  compile:t
    -> link:t
    -> mode:Mode.t
    -> stdlib_dir:Path.t
    -> _ Arg_spec.t

  (** All the library archive files (.a, .cmxa, _stubs.a, ...)  that
      should be linked in when linking an executable. *)
  val archive_files : t -> mode:Mode.t -> Path.t list

  val jsoo_runtime_files : t -> Path.t list

  val remove_dups : t -> t
end

(** Operation on list of libraries and modules *)
module Lib_and_module : sig
  type nonrec t =
    | Lib of t
    | Module of Module.t * Path.t (** obj_dir *)

  val link_flags : t list -> mode:Mode.t -> stdlib_dir:Path.t -> _ Arg_spec.t

end

(** {1 Errors} *)

module Error : sig
  module Library_not_available : sig
    module Reason : sig
      module Hidden : sig
        type t =
          { name   : Lib_name.t
          ; path   : Path.t
          ; reason : string
          }
      end

      type t =
        | Not_found
        | Hidden of Hidden.t

      val to_string : t -> string
      val pp : Format.formatter -> t -> unit
    end

    type nonrec t =
      { loc    : Loc.t (** For names coming from Jbuild files *)
      ; name   : Lib_name.t
      ; reason : Reason.t
      }
  end

  module No_solution_found_for_select : sig
    type t = { loc : Loc.t }
  end

  module Conflict : sig
    (** When two libraries in a transitive closure conflict *)
    type t =
      { lib1 : Lib_info.t * Dep_path.Entry.t list
      ; lib2 : Lib_info.t * Dep_path.Entry.t list
      }
  end

  module Overlap : sig
    (** A conflict that doesn't prevent compilation, but that we still
        consider as an error to avoid surprises. *)
    type t =
      { in_workspace : Lib_info.t
      ; installed    : Lib_info.t * Dep_path.Entry.t list
      }
  end

  module Private_deps_not_allowed : sig
    type t =
      { private_dep : Lib_info.t
      ; loc         : Loc.t
      }
  end

  module Double_implementation : sig
    type t
  end

  module No_implementation : sig
    type t
  end

  type t =
    | Library_not_available        of Library_not_available.t
    | No_solution_found_for_select of No_solution_found_for_select.t
    | Dependency_cycle             of (Path.t * Lib_name.t) list
    | Conflict                     of Conflict.t
    | Overlap                      of Overlap.t
    | Private_deps_not_allowed     of Private_deps_not_allowed.t
    | Double_implementation        of Double_implementation.t
    | No_implementation            of No_implementation.t
end

exception Error of Error.t

(** Raise a error about a library that is not available *)
val not_available
  :  loc:Loc.t
  -> Error.Library_not_available.Reason.t
  -> ('a, Format.formatter, unit, 'b) format4
  -> 'a

(** {1 Compilation contexts} *)

(** See {!Sub_system} *)
type sub_system = ..

(** For compiling a library or executable *)
module Compile : sig
  type t

  (** Return the list of dependencies needed for compiling this library *)
  val requires : t -> L.t Or_exn.t

  (** Dependencies listed by the user + runtime dependencies from ppx *)
  val direct_requires : t -> L.t Or_exn.t

  module Resolved_select : sig
    type t =
      { src_fn : (string, Error.No_solution_found_for_select.t) result
      ; dst_fn : string
      }
  end

  (** Resolved select forms *)
  val resolved_selects : t -> Resolved_select.t list

  (** Transitive closure of all used ppx rewriters *)
  val pps : t -> L.t Or_exn.t

  val optional          : t -> Lib_deps_info.Kind.t
  val user_written_deps : t -> Dune_file.Lib_deps.t

  (** Sub-systems used in this compilation context *)
  val sub_systems : t -> sub_system list
end

(** {1 Library name resolution} *)

(** Collection of libraries organized by names *)
module DB : sig
  type lib = t

  (** A database allow to resolve library names *)
  type t

  module Resolve_result : sig
    type nonrec t =
      | Not_found
      | Found    of Lib_info.t
      | Hidden   of Lib_info.t * string
      | Redirect of t option * Lib_name.t
  end

  (** Create a new library database. [resolve] is used to resolve
      library names in this database.

      When a library is not found, it is looked up in the parent
      database if any.

      [all] returns the list of names of libraries available in this database.
  *)
  val create
    :  ?parent:t
    -> resolve:(Lib_name.t -> Resolve_result.t)
    -> all:(unit -> Lib_name.t list)
    -> unit
    -> t

  (** Create a database from a list of library stanzas *)
  val create_from_library_stanzas
    :  ?parent:t
    -> ext_lib:string
    -> ext_obj:string
    -> (Path.t * Dune_file.Library.t) list
    -> t

  val create_from_findlib
    :  ?external_lib_deps_mode:bool
    -> Findlib.t
    -> t

  val find : t -> Lib_name.t -> (lib, Error.Library_not_available.Reason.t) result
  val find_many
    :  t
    -> loc:Loc.t
    -> Lib_name.t list
    -> lib list Or_exn.t

  val find_even_when_hidden : t -> Lib_name.t -> lib option

  val available : t -> Lib_name.t -> bool

  (** Retrieve the compile information for the given library. Works
      for libraries that are optional and not available as well. *)
  val get_compile_info : t -> ?allow_overlaps:bool -> Lib_name.t -> Compile.t

  val resolve : t -> Loc.t * Lib_name.t -> lib Or_exn.t

  (** Resolve libraries written by the user in a jbuild file. The
      resulting list of libraries is transitively closed and sorted by
      order of dependencies.

      This function is for executables stanzas.  *)
  val resolve_user_written_deps_for_exes
    :  t
    -> ?allow_overlaps:bool
    -> Dune_file.Lib_dep.t list
    -> pps:(Loc.t * Lib_name.t) list
    -> Compile.t

  val resolve_pps
    :  t
    -> (Loc.t * Lib_name.t) list
    -> L.t Or_exn.t

  (** Return the list of all libraries in this database. If
      [recursive] is true, also include libraries in parent databases
      recursively. *)
  val all : ?recursive:bool -> t -> Set.t
end with type lib := t

(** {1 Transitive closure} *)

val closure : L.t -> linking:bool -> L.t Or_exn.t

(** {1 Sub-systems} *)

module Sub_system : sig
  type lib = t

  type t = sub_system = ..

  module type S = sig
    module Info : Dune_file.Sub_system_info.S
    type t
    type sub_system += T of t
    val instantiate
      :  resolve:(Loc.t * Lib_name.t -> lib Or_exn.t)
      -> get:(loc:Loc.t -> lib -> t option)
      -> lib
      -> Info.t
      -> t
    val encode : (t -> Syntax.Version.t * Dune_lang.t) option
  end

  module Register(M : S) : sig
    (** Get the instance of the subsystem for this library *)
    val get : lib -> M.t option
  end

  val dump_config : lib -> (Syntax.Version.t * Dune_lang.t) Sub_system_name.Map.t
end with type lib := t

(** {1 Dependencies for META files} *)

module Meta : sig
  val requires                               : t -> Lib_name.Set.t
  val ppx_runtime_deps                       : t -> Lib_name.Set.t
  val ppx_runtime_deps_for_deprecated_method : t -> Lib_name.Set.t
end
