open Ppxlib

let name = "snarkydef"

let snarky_def ~loc ~path:_ expr =
  [%expr
    with_label
      [%e
        let loc = expr.pexp_loc in
        [%expr
          Pervasives.( ^ ) [%e expr] (Pervasives.( ^ ) ": " Pervasives.__LOC__)]]]

let ext =
  Extension.declare "with_label" Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    snarky_def

let main () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
