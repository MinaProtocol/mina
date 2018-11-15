open Stdune

module Implementation : sig
  type t

  val vlib_dep_graph : t -> Ocamldep.Dep_graphs.t

  val vlib_modules : t -> Lib_modules.t
end

module Gen (S : sig val sctx : Super_context.t end) : sig
  val vlib_stubs_o_files : Implementation.t -> Path.t list

  val setup_copy_rules_for_impl
    :  dir:Path.t
    -> Implementation.t
    -> unit

  val impl
    :  lib:Dune_file.Library.t
    -> scope:Scope.t
    -> modules:Module.Name_map.t
    -> Implementation.t option
end
