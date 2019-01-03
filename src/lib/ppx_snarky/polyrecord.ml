open Core_kernel
open Location
open Ppxlib
open Asttypes
open Ast_helper

let name = "snarky_polyrecord"

let type_name = "polymorphic"

let rec parse_listlike expr =
  match expr.pexp_desc with
  | Pexp_array exprs -> exprs
  | Pexp_tuple exprs -> exprs
  | Pexp_construct
      ({txt= Lident "::"; _}, Some {pexp_desc= Pexp_tuple [hd; tl]; _}) ->
      hd :: parse_listlike tl
  | Pexp_construct ({txt= Lident "[]"; _}, None) -> []
  | _ ->
      raise_errorf ~loc:expr.pexp_loc
        "Could not convert expression into a list of expressions"

let string_of_string_expr expr =
  match expr.pexp_desc with
  | Pexp_constant (Pconst_string (str, None)) -> mkloc str expr.pexp_loc
  | _ ->
      raise_errorf ~loc:expr.pexp_loc
        "Expression is not a string: cannot extract."

let parse_to_name expr =
  match expr.pexp_desc with
  | Pexp_construct (ident, None) -> ident
  | _ ->
      raise_errorf ~loc:expr.pexp_loc
        "Cannot convert this type of expression to a name."

let parse_to_modname expr =
  let name = parse_to_name expr in
  match name.txt with
  | Lident base_name -> mkloc base_name name.loc
  | _ -> raise_errorf ~loc:expr.pexp_loc "Expected a bare module name."

type field_info =
  {field_name: str; field_module: lid; field_snark_module: lid; var_name: str}

let field_module {field_module; _} = field_module

let field_snark_module {field_snark_module; _} = field_snark_module

let loc_map x ~f = mkloc (f x.txt) x.loc

let lid_last x = loc_map x ~f:Longident.last_exn

let ldot mod_name name = mkloc (Ldot (mod_name.txt, name.txt)) name.loc

let ldot' mod_name name = mkloc (Ldot (mod_name.txt, name)) mod_name.loc

let last_common_name lid1 lid2 =
  let names1 = Longident.flatten_exn lid1 in
  let names2 = Longident.flatten_exn lid2 in
  let rec last_equal prev_name names1 names2 =
    match (names1, names2) with
    | a :: names1, b :: names2 when a = b -> last_equal a names1 names2
    | _, _ -> prev_name
  in
  last_equal "unknown" names1 names2

let parse_field ~loc ~instances var_name_map field =
  match parse_listlike field with
  | field_name :: field_module :: rest ->
      let field_name = string_of_string_expr field_name in
      let field_module = parse_to_name field_module in
      let field_module, field_snark_module =
        match (rest, instances) with
        | field_snark_module :: _, _ ->
            (field_module, parse_to_name field_snark_module)
        | [], submodule :: snark_submodule :: _ ->
            (ldot field_module submodule, ldot field_module snark_submodule)
        | _, _ -> raise_errorf ~loc "Not enough instance modules specified"
      in
      let var_name =
        last_common_name field_module.txt field_snark_module.txt
      in
      let rec unique_var_name var_name' i =
        let var_name =
          if i = 0 then var_name else var_name ^ string_of_int i
        in
        match Map.find var_name_map var_name with
        | Some (fld_mod, fld_sn_mod) ->
            if
              Longident.compare field_module.txt fld_mod = 0
              && Longident.compare field_snark_module.txt fld_sn_mod = 0
            then (var_name_map, var_name)
            else unique_var_name var_name' (i + 1)
        | None ->
            let var_name_map =
              Map.add_exn var_name_map ~key:var_name
                ~data:(field_module.txt, field_snark_module.txt)
            in
            (var_name_map, var_name)
      in
      let var_name_map, var_name = unique_var_name var_name 0 in
      let var_name = mkloc var_name field_module.loc in
      (var_name_map, {field_name; field_module; field_snark_module; var_name})
  | _ -> raise_errorf ~loc "Not enough info to construct field"

let parse_content ~loc content =
  match content.pexp_desc with
  | Pexp_variant ("Fold", Some folding_func) -> (
    match parse_listlike folding_func with
    | [name; fold_fn] ->
        let name = string_of_string_expr name in
        (name, fold_fn)
    | _ ->
        raise_errorf ~loc
          "Unexpected format of `Fold. Try `Fold (name, fold_fn)" )
  | _ ->
      raise_errorf ~loc
        "Unexpected format of contents. Try `Fold (name, fold_fn)"

let unique_field_types fields_info =
  List.dedup_and_sort fields_info ~compare:(fun field_info1 field_info2 ->
      String.compare field_info1.var_name.txt field_info2.var_name.txt )

let polymorphic_type_stri ~loc fields_info =
  let fields =
    List.map fields_info ~f:(fun {field_name; var_name; _} ->
        Type.field ~loc field_name (Typ.var ~loc:var_name.loc var_name.txt) )
  in
  let params =
    List.map (unique_field_types fields_info) ~f:(fun {var_name; _} ->
        (Typ.var ~loc:var_name.loc var_name.txt, Invariant) )
  in
  Str.type_ Nonrecursive
    [Type.mk ~loc ~params ~kind:(Ptype_record fields) (mkloc type_name loc)]

let pat_var name = Pat.var ~loc:name.loc name

let accessors_stri ~loc fields_info =
  Str.value ~loc Nonrecursive
    (List.map fields_info ~f:(fun {field_name; _} ->
         let field_ident = loc_map ~f:Longident.parse field_name in
         let name_pat = pat_var field_name in
         let destr_record = Pat.record [(field_ident, name_pat)] Open in
         let accessor_fn =
           Exp.fun_ ~loc:field_name.loc Nolabel None destr_record
             (Exp.ident ~loc:field_ident.loc field_ident)
         in
         Vb.mk ~loc:field_name.loc name_pat accessor_fn ))

let include_ ~loc ?(attr = []) mod_ =
  Str.include_ ~loc {pincl_loc= loc; pincl_attributes= attr; pincl_mod= mod_}

let polymorphic_type_instance_stri ~loc ~field_module fields_info =
  let typs =
    List.map (unique_field_types fields_info) ~f:(fun field_info ->
        Typ.constr (ldot' (field_module field_info) "t") [] )
  in
  let bound_poly = Typ.constr (mkloc (Longident.parse type_name) loc) typs in
  Str.type_ Nonrecursive [Type.mk ~manifest:bound_poly (mkloc "t" loc)]

let t_mod_instance ~loc name fields_info =
  [ Str.module_ ~loc @@ Mb.mk ~loc:name.loc name
    @@ Mod.structure ~loc:name.loc
         [ polymorphic_type_instance_stri ~loc:name.loc ~field_module
             fields_info ]
  ; include_ ~loc (Mod.ident ~loc (loc_map ~f:Longident.parse name)) ]

let rec fold_fun_body ~field_module ~loc ~fname ~foldf ~varname fields_info =
  let field_call field_info =
    Exp.apply ~loc
      (Exp.ident ~loc (ldot' (field_module field_info) fname.txt))
      [ ( Nolabel
        , Exp.field ~loc
            (Exp.ident ~loc:varname.loc (loc_map ~f:Longident.parse varname))
            (loc_map ~f:Longident.parse field_info.field_name) ) ]
  in
  match fields_info with
  | [] ->
      raise_errorf ~loc "Cannot create folding function for empty field list."
  | [field_info] -> field_call field_info
  | field_info :: fields_info ->
      Exp.apply foldf
        [ (Nolabel, field_call field_info)
        ; ( Nolabel
          , fold_fun_body ~field_module ~loc ~fname ~foldf ~varname fields_info
          ) ]

let fold_fun_def ~loc ~field_module ~fname ~foldf ~varname fields_info =
  Vb.mk ~loc (pat_var fname)
    (Exp.fun_ ~loc Nolabel None (pat_var varname)
       (fold_fun_body ~loc ~field_module ~fname ~foldf ~varname fields_info))

let fold_fun_stri ~loc ~field_module ~fname ~foldf ?(varname = "t") fields_info
    =
  Str.value ~loc Nonrecursive
    [ fold_fun_def ~loc ~field_module ~fname:(mkloc fname loc) ~foldf
        ~varname:(mkloc varname loc) fields_info ]

let fields_pattern ~loc fields_info =
  Pat.record ~loc
    (List.map fields_info ~f:(fun {field_name; _} ->
         (loc_map ~f:Longident.parse field_name, pat_var field_name) ))
    Closed

let fields_expression ~loc fields_info =
  Exp.record ~loc
    (List.map fields_info ~f:(fun {field_name; _} ->
         let field_name = loc_map ~f:Longident.parse field_name in
         (field_name, Exp.ident ~loc:field_name.loc field_name) ))
    None

let typ_fold ~loc ~field_module ~fname ~fmod fields_info =
  let mk_lid2 ~loc name1 name2 = mkloc (Ldot (Lident name1, name2)) loc in
  let typ_fn mod_ name =
    Exp.ident ~loc (mkloc (Ldot (Ldot (Lident "Typ", mod_), name)) loc)
  in
  List.fold_left fields_info
    ~init:
      (Exp.apply (typ_fn fmod "return")
         [(Nolabel, fields_expression ~loc fields_info)])
    ~f:(fun expr field_info ->
      Exp.apply (typ_fn fmod "bind")
        [ ( Nolabel
          , Exp.apply ~loc
              (Exp.ident ~loc (mk_lid2 ~loc "Typ" fname))
              [ ( Nolabel
                , Exp.ident ~loc:(field_module field_info).loc
                    (ldot' (field_module field_info) "typ") )
              ; ( Nolabel
                , Exp.ident ~loc:field_info.field_name.loc
                    (loc_map ~f:Longident.parse field_info.field_name) ) ] )
        ; ( Nolabel
          , Exp.fun_ ~loc Nolabel None (pat_var field_info.field_name) expr )
        ] )

let typ_stri ~loc fields_info =
  let field_pattern = fields_pattern ~loc fields_info in
  let field_module = field_snark_module in
  [%stri
    let typ =
      let store [%p field_pattern] =
        [%e
          typ_fold ~loc ~field_module ~fname:"store" ~fmod:"Store" fields_info]
      in
      let read [%p field_pattern] =
        [%e typ_fold ~loc ~field_module ~fname:"read" ~fmod:"Read" fields_info]
      in
      let alloc [%p field_pattern] =
        [%e
          typ_fold ~loc ~field_module ~fname:"alloc" ~fmod:"Alloc" fields_info]
      in
      let check [%p field_pattern] =
        [%e
          typ_fold ~loc ~field_module ~fname:"check" ~fmod:"Check" fields_info]
      in
      {store; read; alloc; check}]

let snark_mod_instance ~loc modname fields_info contents_info =
  let field_module = field_snark_module in
  let contents =
    List.map contents_info ~f:(fun (fname, foldf) ->
        fold_fun_stri ~loc:fname.loc ~field_module ~fname:fname.txt ~foldf
          fields_info )
  in
  [ Str.module_
    @@ Mb.mk ~loc:modname.loc modname
    @@ Mod.structure ~loc:modname.loc
         ( polymorphic_type_instance_stri ~loc:modname.loc ~field_module
             fields_info
         :: typ_stri ~loc fields_info :: contents ) ]

let instances_str ~loc instances_info fields_info contents_info =
  match instances_info with
  | [] -> []
  | [t_mod] -> t_mod_instance ~loc t_mod fields_info
  | t_mod :: snark_mod :: _ ->
      t_mod_instance ~loc t_mod fields_info
      @ snark_mod_instance ~loc snark_mod fields_info contents_info

let parse_arguments expr =
  List.map (parse_listlike expr) ~f:(fun expr ->
      match expr.pexp_desc with
      | Pexp_variant (variant_name, Some variant_info) ->
          (variant_name, variant_info)
      | _ ->
          raise_errorf ~loc:expr.pexp_loc
            "Expected a variant type. Try `Instances (T, Snarkable)" )

let read_arg ~arguments name =
  List.Assoc.find arguments name ~equal:String.equal

let read_arg_exn ~loc ~arguments name =
  match read_arg ~arguments name with
  | Some instances_info -> instances_info
  | None -> raise_errorf ~loc "Expected an %s argument." name

let str_poly_record ~loc ~path:_ expr =
  let arguments = parse_arguments expr in
  let instances_info =
    read_arg_exn ~loc:expr.pexp_loc ~arguments "Instances"
    |> parse_listlike
    |> List.map ~f:parse_to_modname
  in
  let fields_info =
    read_arg_exn ~loc:expr.pexp_loc ~arguments "Fields"
    |> parse_listlike
    |> List.folding_map
         ~init:(Map.empty (module String))
         ~f:(parse_field ~instances:instances_info ~loc)
  in
  let contents_info =
    match read_arg ~arguments "Contents" with
    | Some contents_info ->
        List.map ~f:(parse_content ~loc) (parse_listlike contents_info)
    | None -> []
  in
  let polytype = polymorphic_type_stri ~loc fields_info in
  let accessors = accessors_stri ~loc fields_info in
  let instances =
    instances_str ~loc instances_info fields_info contents_info
  in
  include_ ~loc (Mod.structure ~loc (polytype :: accessors :: instances))

let ext =
  Extension.declare "polymorphic_record" Extension.Context.structure_item
    Ast_pattern.(single_expr_payload __)
    str_poly_record

let main () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
