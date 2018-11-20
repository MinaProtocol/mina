(** OCaml module compilation *)

open Import

(** Setup rules to build a single module.

    @param dynlink if false disables the possibility to dynamically
    link. The module can't be in a .cmxs or .so (default true).
 *)
val build_module
  :  ?sandbox:bool
  -> ?js_of_ocaml:Dune_file.Js_of_ocaml.t
  -> ?dynlink:bool
  -> dep_graphs:Ocamldep.Dep_graphs.t
  -> Compilation_context.t
  -> Module.t
  -> unit

(** Setup rules to build all of the modules in the compilation context. *)
val build_modules
  :  ?sandbox:bool
  -> ?js_of_ocaml:Dune_file.Js_of_ocaml.t
  -> ?dynlink:bool
  -> dep_graphs:Ocamldep.Dep_graphs.t
  -> Compilation_context.t
  -> unit

val ocamlc_i
  :  ?sandbox:bool
  -> ?flags:string list
  -> dep_graphs:Ocamldep.Dep_graphs.t
  -> Compilation_context.t
  -> Module.t
  -> output:Path.t
  -> unit
