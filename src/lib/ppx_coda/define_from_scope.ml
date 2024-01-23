open Core_kernel
open Ppxlib
open Asttypes

(* define_from_scope creates local definitions from those in scope

   Example:

     [%%define_from_scope x,y,z]

   expands to

     let x,y,z = x,y,z

   Useful when importing definitions from an enclosing scope:

     let x = ...
     let y = ...

     module T = struct
       [%%define_from_scope x,y]
     end
*)

let name = "define_from_scope"

let expr_to_id loc expr =
  match expr.pexp_desc with
  | Pexp_ident { txt = Lident s; _ } ->
      s
  | _ ->
      Location.raise_errorf ~loc "Expected identifier"

let expand ~loc ~path:_ (items : expression list) =
  let (module Ast_builder) = Ast_builder.make loc in
  let open Ast_builder in
  let ids = List.map items ~f:(expr_to_id loc) in
  let vars = List.map ids ~f:evar in
  let pats = List.map ids ~f:pvar in
  [%stri let [%p ppat_tuple pats] = [%e pexp_tuple vars]]

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (pexp_tuple __))
    expand

let () =
  Driver.register_transformation name ~rules:[ Context_free.Rule.extension ext ]
