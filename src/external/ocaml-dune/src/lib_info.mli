(** {1 Raw library descriptions} *)

open Stdune

module Status : sig
  type t =
    | Installed
    | Public  of Package.t
    | Private of Dune_project.Name.t

  val pp : t Fmt.t

  val is_private : t -> bool
end

module Deps : sig
  type t =
    | Simple  of (Loc.t * Lib_name.t) list
    | Complex of Dune_file.Lib_dep.t list

  val of_lib_deps : Dune_file.Lib_deps.t -> t
end

module Virtual : sig
  module Modules : sig
    type t = private
      | Unexpanded
  end

  module Dep_graph : sig
    type t = private
      | Local
  end

  type t = private
    { modules   : Modules.t
    ; dep_graph : Dep_graph.t
    }
end

type t = private
  { loc              : Loc.t
  ; name             : Lib_name.t
  ; kind             : Dune_file.Library.Kind.t
  ; status           : Status.t
  ; src_dir          : Path.t
  ; obj_dir          : Path.t
  ; private_obj_dir  : Path.t option
  ; version          : string option
  ; synopsis         : string option
  ; archives         : Path.t list Mode.Dict.t
  ; plugins          : Path.t list Mode.Dict.t
  ; foreign_objects  : Path.t list
  ; foreign_archives : Path.t list Mode.Dict.t (** [.a/.lib/...] files *)
  ; jsoo_runtime     : Path.t list
  ; jsoo_archive     : Path.t option
  ; requires         : Deps.t
  ; ppx_runtime_deps : (Loc.t * Lib_name.t) list
  ; pps              : (Loc.t * Lib_name.t) list
  ; optional         : bool
  ; virtual_deps     : (Loc.t * Lib_name.t) list
  ; dune_version : Syntax.Version.t option
  ; sub_systems      : Dune_file.Sub_system_info.t Sub_system_name.Map.t
  ; virtual_         : Virtual.t option
  ; implements       : (Loc.t * Lib_name.t) option
  ; main_module_name : Dune_file.Library.Main_module_name.t
  }

val of_library_stanza
  : dir:Path.t
  -> ext_lib:string
  -> ext_obj:string
  -> Dune_file.Library.t
  -> t

val of_findlib_package : Findlib.Package.t -> t

val user_written_deps : t -> Dune_file.Lib_deps.t
