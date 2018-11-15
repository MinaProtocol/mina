open! Stdune
open! Import

(* Generate rules. Returns evaluated jbuilds per context names. *)
val gen
  :  contexts:Context.t list
  -> build_system:Build_system.t
  -> ?external_lib_deps_mode:bool (* default: false *)
  -> ?only_packages:Package.Name.Set.t
  -> Dune_load.conf
  -> Super_context.t String.Map.t Fiber.t
