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

let pat_of_id loc id =
  {ppat_desc= Ppat_var {txt= id; loc}; ppat_loc= loc; ppat_attributes= []}

let ident_of_id loc id =
  { pexp_desc= Pexp_ident {txt= Lident id; loc}
  ; pexp_loc= loc
  ; pexp_attributes= [] }

let expr_to_id loc expr =
  match expr.pexp_desc with
  | Pexp_ident {txt= Lident s; _} ->
      s
  | _ ->
      Location.raise_errorf ~loc "Expected identifier"

let expand ~loc ~path:_ (items : expression list) =
  let ids = List.map items ~f:(expr_to_id loc) in
  let pats = List.map ids ~f:(pat_of_id loc) in
  let idents = List.map ids ~f:(ident_of_id loc) in
  { pstr_desc=
      Pstr_value
        ( Nonrecursive
        , [ { pvb_pat=
                {ppat_desc= Ppat_tuple pats; ppat_loc= loc; ppat_attributes= []}
            ; pvb_expr=
                { pexp_desc= Pexp_tuple idents
                ; pexp_loc= loc
                ; pexp_attributes= [] }
            ; pvb_attributes= []
            ; pvb_loc= loc } ] )
  ; pstr_loc= loc }

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (pexp_tuple __))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
