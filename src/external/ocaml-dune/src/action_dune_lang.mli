(* This module is to be used in Dune_file. It should not introduce any
    dependencies unless they're already dependencies of Dune_file *)
include Action_intf.Ast
  with type program := String_with_vars.t and
  type string := String_with_vars.t and
  type path := String_with_vars.t

include Dune_lang.Conv with type t := t

include Action_intf.Helpers
  with type t := t and
  type program = String_with_vars.t and
  type string = String_with_vars.t and
  type path = String_with_vars.t

