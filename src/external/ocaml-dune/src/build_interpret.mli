open! Stdune
open! Import

module Target : sig
  type t =
    | Normal of Path.t
    | Vfile : _ Build.Vspec.t -> t

  val path : t -> Path.t
  val paths : t list -> Path.Set.t
end

module Rule : sig
  type t =
    { context  : Context.t option
    ; env      : Env.t option
    ; build    : (unit, Action.t) Build.t
    ; targets  : Target.t list
    ; sandbox  : bool
    ; mode     : Dune_file.Rule.Mode.t
    ; locks    : Path.t list
    ; loc      : Loc.t option
    ; (** Directory where all the targets are produced *)
      dir      : Path.t
    }

  val make
    :  ?sandbox:bool
    -> ?mode:Dune_file.Rule.Mode.t
    -> context:Context.t option
    -> env:Env.t option
    -> ?locks:Path.t list
    -> ?loc:Loc.t
    -> (unit, Action.t) Build.t
    -> t
end

(* must be called first *)
val static_deps
  :  (_, _) Build.t
  -> all_targets:(dir:Path.t -> Path.Set.t)
  -> file_tree:File_tree.t
  -> Static_deps.t

val lib_deps
  :  (_, _) Build.t
  -> Lib_deps_info.t

val targets
  :  (_, _) Build.t
  -> Target.t list
