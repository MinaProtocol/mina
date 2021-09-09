open Core_kernel
open Ppxlib
open Asttypes
open Ast_helper

(* define_locally mirrors local definitions from some other module

   Example:

     [%%define_locally M.(x,y,z)]

   expands to

     let x,y,z = M.(x,y,z)

 *)

let name = "define_locally"

let raise_errorf = Location.raise_errorf

let expand ~loc ~path:_ override (module_name : longident) defs =
  match defs.pexp_desc with
  | Pexp_tuple exps ->
      let names =
        List.map exps ~f:(fun {pexp_desc= item; pexp_loc= loc; _} ->
            match item with
            | Pexp_ident {txt= Lident id; _} ->
                id
            | __ ->
                raise_errorf ~loc "Item in opened module is not an identifier"
        )
      in
      let vars =
        List.map names ~f:(fun name -> Pat.var ~loc {txt= name; loc})
      in
      Str.value ~loc Nonrecursive
        [ Vb.mk ~loc (Pat.tuple ~loc vars)
            (Exp.open_ ~loc override {txt= module_name; loc} defs) ]
  | Pexp_ident {txt= Lident id; _} ->
      Str.value ~loc Nonrecursive
        [ Vb.mk ~loc
            (Pat.var ~loc {txt= id; loc})
            (Exp.open_ ~loc override {txt= module_name; loc} defs) ]
  | _ ->
      raise_errorf ~loc "Must provide an identifier or tuple of identifiers"

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (pexp_open __ __ __))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
