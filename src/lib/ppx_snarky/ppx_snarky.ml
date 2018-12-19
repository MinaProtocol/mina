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
      field_mod |> parse_to_name |> Longident.last_exn
      |> String.uncapitalize_ascii
  | _ -> failwith "Not enough info to construct type var."

let polymorphic_type_stri fields_info =
  let typ_vars = List.map type_var fields_info in
  let fields =
    fields_info
    |> List.map2
         (fun typ_var field_info ->
           match field_info with
           | field_name :: _ ->
               let field_name = mknoloc (string_of_string_expr field_name) in
               Type.field field_name (Typ.var typ_var)
           | _ -> failwith "Not enough info to construct polymorphic type." )
         typ_vars
  in
  let params =
    typ_vars |> List.map (fun typ_var -> (Typ.var typ_var, Invariant))
  in
  Str.type_ Nonrecursive
    [Type.mk ~params ~kind:(Ptype_record fields) (mknoloc "polymorphic")]

let accessors_stri fields_info =
  let accessor_bindings =
    List.map (fun field_info ->
        match field_info with
        | field_name :: _ ->
            let field_name = string_of_string_expr field_name in
            let field_ident = mknoloc (Longident.parse field_name) in
            let name_pat = Pat.var (mknoloc field_name) in
            let destr_record = Pat.record [(field_ident, name_pat)] Open in
            let accessor_fn =
              Exp.fun_ Nolabel None destr_record (Exp.ident field_ident)
            in
            Vb.mk name_pat accessor_fn
        | _ -> failwith "Not enough info to construct accessors." )
  in
  Str.value Nonrecursive (accessor_bindings fields_info)

let include_ ?(loc = none) ?(attr = []) mod_ =
  Str.include_ ~loc {pincl_loc= loc; pincl_attributes= attr; pincl_mod= mod_}

let t_mod_instance name _fields_info =
  [ Str.module_ @@ Mb.mk (mknoloc name) @@ Mod.structure []
  ; include_ (Mod.ident (mknoloc (Longident.parse name))) ]

let snark_mod_instance name _fields_info =
  [Str.module_ @@ Mb.mk (mknoloc name) @@ Mod.structure []]

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
        instances_info |> parse_listlike |> List.map parse_to_name
      in
      let fields_info =
        fields_info |> parse_listlike |> List.map parse_listlike
      in
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
