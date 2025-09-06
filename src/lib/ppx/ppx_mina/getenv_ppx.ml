open Ppxlib

let name = "getenv"

let expand ~loc ~path:_ var =
  match Caml.Sys.getenv var with
  | s ->
      [%expr Some [%e Ast_builder.Default.estring s ~loc]]
  | exception Not_found ->
      [%expr None]

let ext =
  Extension.declare name Extension.Context.expression
    Ast_pattern.(single_expr_payload (estring __))
    expand

let () =
  Driver.register_transformation name ~rules:[ Context_free.Rule.extension ext ]
