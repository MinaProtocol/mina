open Core_kernel
open Location
open Ppxlib
open Asttypes
open Ast_helper

let name = "snarky"

let parse_listlike expr =
  match expr.pexp_desc with
  | Pexp_array exprs -> exprs
  | Pexp_tuple exprs -> exprs
  | _ -> failwith "Could not convert expression into a list of expressions"

let string_of_string_expr expr =
  match expr.pexp_desc with
  | Pexp_constant (Pconst_string (str, None)) -> str
  | _ -> failwith "Expression is not a string: cannot extract."

let parse_to_name expr =
  match expr.pexp_desc with
  (*| Pexp_ident ident -> ident.txt*)
  | Pexp_construct (ident, None) -> ident.txt
  | _ -> failwith "Cannot convert this type of expression to a name."

let type_var field_info =
  match field_info with
  | _ :: field_mod :: _ ->
      field_mod |> parse_to_name |> Longident.last_exn |> String.uncapitalize
  | _ -> failwith "Not enough info to construct type var."

type field_info =
  {field_name: string; field_module: Longident.t; var_name: string}

let parse_field field =
  match parse_listlike field with
  | field_name :: field_module :: _ ->
      let field_name = string_of_string_expr field_name in
      let field_module = parse_to_name field_module in
      let var_name = String.uncapitalize (Longident.last_exn field_module) in
      {field_name; field_module; var_name}
  | _ -> failwith "Not enough info to construct field"

let polymorphic_type_stri fields_info =
  let fields =
    List.map fields_info ~f:(fun field_info ->
        Type.field
          (mknoloc field_info.field_name)
          (Typ.var field_info.var_name) )
  in
  let params =
    List.map fields_info ~f:(fun {var_name; _} -> (Typ.var var_name, Invariant))
  in
  Str.type_ Nonrecursive
    [Type.mk ~params ~kind:(Ptype_record fields) (mknoloc "polymorphic")]

let accessors_stri fields_info =
  Str.value Nonrecursive
    (List.map fields_info ~f:(fun {field_name; _} ->
         let field_ident = mknoloc (Longident.parse field_name) in
         let name_pat = Pat.var (mknoloc field_name) in
         let destr_record = Pat.record [(field_ident, name_pat)] Open in
         let accessor_fn =
           Exp.fun_ Nolabel None destr_record (Exp.ident field_ident)
         in
         Vb.mk name_pat accessor_fn ))

let include_ ?(loc = none) ?(attr = []) mod_ =
  Str.include_ ~loc {pincl_loc= loc; pincl_attributes= attr; pincl_mod= mod_}

let localize_mod base_mod mod_name name = Ldot (Ldot (base_mod, mod_name), name)

let polymorphic_type_instance_stri mod_name fields_info =
  let typs =
    List.map fields_info ~f:(fun {field_module; _} ->
        let path = localize_mod field_module mod_name "t" in
        Typ.constr (mknoloc path) [] )
  in
  let bound_poly = Typ.constr (mknoloc (Longident.parse "polymorphic")) typs in
  Str.type_ Nonrecursive [Type.mk ~manifest:bound_poly (mknoloc "polymorphic")]

let t_mod_instance name fields_info =
  [ Str.module_
    @@ Mb.mk (mknoloc name)
    @@ Mod.structure [polymorphic_type_instance_stri name fields_info]
  ; include_ (Mod.ident (mknoloc (Longident.parse name))) ]

let snark_mod_instance name fields_info =
  [ Str.module_
    @@ Mb.mk (mknoloc name)
    @@ Mod.structure [polymorphic_type_instance_stri name fields_info] ]

let instances_str instances_info fields_info =
  match instances_info with
  | [] -> []
  | [t_mod] -> t_mod_instance (Longident.last_exn t_mod) fields_info
  | t_mod :: snark_mod :: _ ->
      t_mod_instance (Longident.last_exn t_mod) fields_info
      @ snark_mod_instance (Longident.last_exn snark_mod) fields_info

let str_poly_record ~loc ~path:_ expr =
  match expr with
  | { pexp_desc=
        Pexp_tuple
          [ {pexp_desc= Pexp_variant ("Instances", Some instances_info); _}
          ; {pexp_desc= Pexp_variant ("Fields", Some fields_info); _} ]; _ } ->
      let instances_info =
        instances_info |> parse_listlike |> List.map ~f:parse_to_name
      in
      let fields_info = List.map ~f:parse_field (parse_listlike fields_info) in
      let polytype = polymorphic_type_stri fields_info in
      let accessors = accessors_stri fields_info in
      let instances = instances_str instances_info fields_info in
      include_ ~loc (Mod.structure (polytype :: accessors :: instances))
  | _ -> failwith "no!"

let ext =
  Extension.declare "polymorphic_record" Extension.Context.structure_item
    Ast_pattern.(single_expr_payload __)
    str_poly_record

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
