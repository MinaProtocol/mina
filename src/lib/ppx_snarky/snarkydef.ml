open Ppxlib
open Ast_helper
open Ast_builder.Default
open Asttypes

let name = "snarkydef"

let located_label_expr expr =
  let loc = expr.pexp_loc in
  [%expr Pervasives.( ^ ) [%e expr] (Pervasives.( ^ ) ": " Pervasives.__LOC__)]

let located_label_string ~loc str =
  [%expr
    Pervasives.( ^ )
      [%e Exp.constant ~loc (Const.string (str ^ ": "))]
      Pervasives.__LOC__]

let with_label ~loc exprs = Exp.apply ~loc [%expr with_label] exprs

let with_label_one ~loc ~path:_ expr =
  with_label ~loc [(Nolabel, located_label_expr expr)]

let rec snarkydef_inject ~loc ~name expr =
  match expr.pexp_desc with
  | Pexp_fun (lbl, default, pat, body) ->
      { expr with
        pexp_desc=
          Pexp_fun (lbl, default, pat, snarkydef_inject ~loc ~name body) }
  | Pexp_newtype (typname, body) ->
      { expr with
        pexp_desc= Pexp_newtype (typname, snarkydef_inject ~loc ~name body) }
  | Pexp_function _ ->
      Location.raise_errorf ~loc:expr.pexp_loc
        "%%snarkydef currently doesn't support 'function'"
  | _ ->
      with_label ~loc
        [(Nolabel, located_label_string ~loc name); (Nolabel, expr)]

let snarkydef ~loc ~path:_ name expr =
  [%stri
    let [%p Pat.var ~loc (Located.mk ~loc name)] =
      [%e snarkydef_inject ~loc ~name expr]]

let with_label_ext =
  Extension.declare "with_label" Extension.Context.expression
    Ast_pattern.(single_expr_payload __)
    with_label_one

let snarkydef_ext =
  Extension.declare "snarkydef" Extension.Context.structure_item
    Ast_pattern.(
      pstr
        ( pstr_value nonrecursive
            (value_binding ~pat:(ppat_var __) ~expr:__ ^:: nil)
        ^:: nil ))
    snarkydef

let main () =
  Driver.register_transformation name
    ~rules:
      [ Context_free.Rule.extension with_label_ext
      ; Context_free.Rule.extension snarkydef_ext ]
