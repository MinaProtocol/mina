open! Stdune

type program = String_with_vars.t
type string = String_with_vars.t
type path = String_with_vars.t

module type Uast = Action_intf.Ast
  with type program = String_with_vars.t
  with type path    = String_with_vars.t
  with type string  = String_with_vars.t
module rec Uast : Uast = Uast
include Action_ast.Make(String_with_vars)(String_with_vars)(String_with_vars)(Uast)


open Dune_lang.Decoder
let decode =
  if_list
    ~then_:decode
    ~else_:
      (loc >>| fun loc ->
       of_sexp_errorf
         loc
         "if you meant for this to be executed with bash, write (bash \"...\") instead")
