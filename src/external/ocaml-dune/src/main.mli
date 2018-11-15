open! Stdune
open! Import

type setup =
  { build_system : Build_system.t
  ; contexts     : Context.t list
  ; scontexts    : Super_context.t String.Map.t
  ; packages     : Package.t Package.Name.Map.t
  ; file_tree    : File_tree.t
  ; env          : Env.t
  }

(* Returns [Error ()] if [pkg] is unknown *)
val package_install_file : setup -> Package.Name.t -> (Path.t, unit) result

(** Scan the source tree and discover everything that's needed in order to build
    it. *)
val setup
  :  ?log:Log.t
  -> ?external_lib_deps_mode:bool
  -> ?workspace:Workspace.t
  -> ?workspace_file:Path.t
  -> ?only_packages:Package.Name.Set.t
  -> ?x:string
  -> ?ignore_promoted_rules:bool
  -> ?capture_outputs:bool
  -> ?profile:string
  -> unit
  -> setup Fiber.t
val external_lib_deps
  : ?log:Log.t
  -> packages:Package.Name.t list
  -> unit
  -> Lib_deps_info.t Path.Map.t

val find_context_exn : setup -> name:string -> Context.t

(** Setup the environment *)
val setup_env : capture_outputs:bool -> Env.t

(** Set the concurrency level according to the user configuration *)
val set_concurrency : ?log:Log.t -> Config.t -> unit Fiber.t

(**/**)

(* This is used to bootstrap dune itself. It is not part of the public API. *)
val bootstrap : unit -> unit
