(* deriving.ml -- deriving ppx for Dhall types *)

(* TODO:
    deriver for signatures
    default values in records
*)

open Core_kernel
open Ppxlib

let deriver = "dhall_type"

let field_key_attr =
  Attribute.declare (deriver ^ ".key") Attribute.Context.Label_declaration
    Ast_pattern.(single_expr_payload (estring __))
    Fn.id

let make_lident_cmp items lident =
  List.mem items (Longident.name lident.txt) ~equal:String.equal

let is_bool_lident = make_lident_cmp ["bool"; "Bool.t"]

let is_int_lident = make_lident_cmp ["int"; "Int.t"]

let is_float_lident = make_lident_cmp ["float"; "Float.t"]

let is_string_lident = make_lident_cmp ["string"; "String.t"]

let is_option_lident = make_lident_cmp ["option"; "Option.t"]

let is_list_lident = make_lident_cmp ["list"; "List.t"]

let rec dhall_type_of_core_type core_type =
  let (module Ast_builder) = Ast_builder.make core_type.ptyp_loc in
  let open Ast_builder in
  match core_type.ptyp_desc with
  | Ptyp_constr (lident, []) when is_bool_lident lident ->
      [%expr Ppx_dhall_type.Dhall_type.Bool]
  | Ptyp_constr (lident, []) when is_int_lident lident ->
      [%expr Ppx_dhall_type.Dhall_type.Integer]
  | Ptyp_constr (lident, []) when is_float_lident lident ->
      [%expr Ppx_dhall_type.Dhall_type.Double]
  | Ptyp_constr (lident, []) when is_string_lident lident ->
      [%expr Ppx_dhall_type.Dhall_type.Text]
  | Ptyp_constr (lident, [ty]) when is_option_lident lident ->
      [%expr
        Ppx_dhall_type.Dhall_type.Optional [%e dhall_type_of_core_type ty]]
  | Ptyp_constr (lident, [ty]) when is_list_lident lident ->
      [%expr Ppx_dhall_type.Dhall_type.List [%e dhall_type_of_core_type ty]]
  | Ptyp_constr ({txt= Lident id; _}, []) ->
      evar (id ^ "_dhall_type")
  | Ptyp_constr ({txt= Lident id; _}, params) ->
      let dhall_type_fun = evar (id ^ "_dhall_type") in
      let args = List.map params ~f:dhall_type_of_core_type in
      eapply dhall_type_fun args
  | Ptyp_constr ({txt= Ldot (prefix, nm); _}, []) ->
      let mod_path = Longident.name prefix in
      if String.equal nm "t" then evar (mod_path ^ ".dhall_type")
      else evar (mod_path ^ "." ^ nm ^ "_dhall_type")
  | Ptyp_constr ({txt= Ldot (prefix, nm); _}, params) ->
      let mod_path = Longident.name prefix in
      let dhall_type_fun =
        if String.equal nm "t" then evar (mod_path ^ ".dhall_type")
        else evar (mod_path ^ "." ^ nm ^ "_dhall_type")
      in
      let args = List.map params ~f:dhall_type_of_core_type in
      eapply dhall_type_fun args
  | Ptyp_var a ->
      evar a
  | _ ->
      Location.raise_errorf ~loc:core_type.ptyp_loc "Unsupported type"

let dhall_variant_from_constructor_declaration ctor_decl =
  let (module Ast_builder) = Ast_builder.make ctor_decl.pcd_name.loc in
  let open Ast_builder in
  let name = estring @@ String.lowercase ctor_decl.pcd_name.txt in
  match ctor_decl.pcd_args with
  | Pcstr_tuple [] ->
      [%expr [%e name], None]
  | Pcstr_tuple [ty] ->
      [%expr [%e name], Some [%e dhall_type_of_core_type ty]]
  | Pcstr_tuple tys ->
      let tys_expr = elist (List.map tys ~f:dhall_type_of_core_type) in
      [%expr [%e name], Some (List [%e tys_expr])]
  | Pcstr_record _ ->
      Location.raise_errorf ~loc:ctor_decl.pcd_name.loc
        "Records not yet supported"

let dhall_field_from_label_declaration label_decl =
  let (module Ast_builder) = Ast_builder.make label_decl.pld_name.loc in
  let open Ast_builder in
  let name =
    match Attribute.get field_key_attr label_decl with
    | Some name ->
        estring name
    | None ->
        estring label_decl.pld_name.txt
  in
  let ty = dhall_type_of_core_type label_decl.pld_type in
  [%expr [%e name], [%e ty]]

let generate_dhall_type type_decl =
  let (module Ast_builder) = Ast_builder.make type_decl.ptype_loc in
  let open Ast_builder in
  let dhall_type =
    match type_decl.ptype_kind with
    | Ptype_abstract -> (
      match type_decl.ptype_manifest with
      | None ->
          Location.raise_errorf ~loc:type_decl.ptype_loc
            "Abstract type declaration has no manifest (right-hand side)"
      | Some core_type ->
          dhall_type_of_core_type core_type )
    | Ptype_variant ctor_decls ->
        [%expr
          Ppx_dhall_type.Dhall_type.Union
            [%e
              elist
                (List.map ctor_decls
                   ~f:dhall_variant_from_constructor_declaration)]]
    | Ptype_record label_decls ->
        [%expr
          Ppx_dhall_type.Dhall_type.Record
            [%e
              elist
                (List.map label_decls ~f:dhall_field_from_label_declaration)]]
    | Ptype_open ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Open types not supported"
  in
  let ty_name =
    match type_decl.ptype_name.txt with
    | "t" ->
        pvar "dhall_type"
    | nm ->
        pvar (nm ^ "_dhall_type")
  in
  match type_decl.ptype_params with
  | [] ->
      [%stri let [%p ty_name] = [%e dhall_type]]
  | params ->
      let args =
        List.map params ~f:(fun (core_type, _variance) ->
            match core_type.ptyp_desc with
            | Ptyp_var a ->
                pvar a
            | _ ->
                Location.raise_errorf ~loc:type_decl.ptype_loc
                  "Type parameter not a type variable" )
      in
      let abs = eabstract args dhall_type in
      [%stri let [%p ty_name] = [%e abs]]

let generate_dhall_types ~loc:_ ~path:_ (_rec_flag, type_decls) =
  List.map type_decls ~f:generate_dhall_type

let attributes = [Attribute.T field_key_attr]

let str_type_decl =
  Deriving.Generator.make_noarg ~attributes generate_dhall_types

let () = Deriving.add deriver ~str_type_decl |> Ppxlib.Deriving.ignore
