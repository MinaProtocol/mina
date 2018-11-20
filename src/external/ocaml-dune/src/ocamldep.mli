(** ocamldep management *)

open Stdune

module Dep_graph : sig
  type t

  val deps_of
    :  t
    -> Module.t
    -> (unit, Module.t list) Build.t

  val top_closed_implementations
    :  t
    -> Module.t list
    -> (unit, Module.t list) Build.t

  val top_closed_multi_implementations
    :  t list
    -> Module.t list
    -> (unit, Module.t list) Build.t
end

module Dep_graphs : sig
  type t = Dep_graph.t Ml_kind.Dict.t

  val dummy : Module.t -> t

  val wrapped_compat
    :  modules:Module.t Module.Name.Map.t
    -> wrapped_compat:Module.t Module.Name.Map.t
    -> t

  val merge_for_impl : vlib:t -> impl:t -> t
end

(** Generate ocamldep rules for all the modules in the context. *)
val rules : Compilation_context.t -> Dep_graphs.t

(** Compute the dependencies of an auxiliary module. *)
val rules_for_auxiliary_module
  :  Compilation_context.t
  -> Module.t
  -> Dep_graphs.t

(** Get the dep graph for an already defined library *)
val graph_of_remote_lib
  :  obj_dir:Path.t
  -> modules:Module.t Module.Name.Map.t
  -> Dep_graph.t Ml_kind.Dict.t
