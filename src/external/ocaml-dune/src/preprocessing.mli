(** Preprocessing of OCaml source files *)

open! Stdune
open! Import

(** Preprocessing object *)
type t

val dummy : t

val make
  :  Super_context.t
  -> dir:Path.t
  -> dep_kind:Lib_deps_info.Kind.t
  -> lint:Dune_file.Preprocess_map.t
  -> preprocess:Dune_file.Preprocess_map.t
  -> preprocessor_deps:(unit, Path.t list) Build.t
  -> lib_name:Lib_name.Local.t option
  -> scope:Scope.t
  -> dir_kind:Dune_lang.Syntax.t
  -> t

(** Setup the preprocessing rules for the following modules and
    returns the translated modules *)
val pp_modules
  :  t
  -> ?lint:bool
  -> Module.t Module.Name.Map.t
  -> Module.t Module.Name.Map.t

(** Preprocess a single module, using the configuration for the given
    module name. *)
val pp_module_as
  :  t
  -> ?lint:bool
  -> Module.Name.t
  -> Module.t
  -> Module.t

(** Get a path to a cached ppx driver *)
val get_ppx_driver
  :  Super_context.t
  -> scope:Scope.t
  -> dir_kind:Dune_lang.Syntax.t
  -> (Loc.t * Lib_name.t) list
  -> Path.t Or_exn.t

module Compat_ppx_exe_kind : sig
  (** [Dune] for directories using a [dune] file, and [Jbuild driver]
      for directories using a [jbuild] file. *)
  type t =
    | Dune
    | Jbuild of string option
end

(** Compatibility [ppx.exe] program for the findlib method. *)
val get_compat_ppx_exe
  :  Super_context.t
  -> name:Lib_name.t
  -> kind:Compat_ppx_exe_kind.t
  -> Path.t

(** [cookie_library_name lib_name] is ["--cookie"; lib_name] if [lib_name] is not
    [None] *)
val cookie_library_name : Lib_name.Local.t option -> string list

val gen_rules : Super_context.t -> string list -> unit
