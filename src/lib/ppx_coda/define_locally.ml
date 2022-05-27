open Core_kernel
open Ppxlib

(* define_locally mirrors local definitions from some other module

   Example:

     [%%define_locally M.(x,y,z)]

   expands to

     let x,y,z = M.(x,y,z)
*)

let name = "define_locally"

let raise_errorf = Location.raise_errorf

let expr_to_id loc expr =
  match expr.pexp_desc with
  | Pexp_ident { txt = Lident s; _ } ->
      s
  | _ ->
      Location.raise_errorf ~loc "Expected identifier"

let expand ~loc ~path:_ open_decl defs =
  let (module Ast_builder) = Ast_builder.make loc in
  let open Ast_builder in
  match defs.pexp_desc with
  | Pexp_tuple exps ->
      let names = List.map exps ~f:(expr_to_id loc) in
      let vars = List.map names ~f:pvar in
      pstr_value Nonrecursive
        [ value_binding ~pat:(ppat_tuple vars)
            ~expr:(pexp_open open_decl defs)
        ]
  | Pexp_ident { txt = Lident id; _ } ->
      pstr_value Nonrecursive
        [ value_binding ~pat:(ppat_var {txt = id; loc})
            ~expr:(pexp_open open_decl defs)
        ]
  | _ ->
      raise_errorf ~loc "Must provide an identifier or tuple of identifiers"

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (pexp_open __ __))
    expand

let () =
  Driver.register_transformation name ~rules:[ Context_free.Rule.extension ext ]
