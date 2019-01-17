open Core_kernel
open Location
open Ppxlib
open Ast_helper

type lbl = label Location.loc

type longident = Ast.longident =
  | Lident of string
  | Ldot of longident * string
  | Lapply of longident * longident
[@@deriving sexp]

type lid = longident Location.loc

let sexp_of_lid {txt; _} = sexp_of_longident txt

let lid_of_sexp sexp = {txt= longident_of_sexp sexp; loc= Location.none}

type modinfo = ModuleName of lid | IdentName of lid | BaseModule of lid

let cmp_modinfo x y =
  match (x, y) with
  | ModuleName x, ModuleName y
   |IdentName x, IdentName y
   |BaseModule x, BaseModule y ->
      Pervasives.compare x.txt y.txt
  | ModuleName _, _ -> -1
  | _, ModuleName _ -> 1
  | IdentName _, _ -> -1
  | _, IdentName _ -> 1

let parse_to_modinfo expr =
  match expr.pexp_desc with
  | Pexp_construct (ident, None) -> ModuleName ident
  | Pexp_ident ({txt= Ldot _; _} as ident) -> IdentName ident
  | _ ->
      raise_errorf ~loc:expr.pexp_loc
        "Expected a bare module name or a type identifier of form \
         Module_name.type_name"

type field =
  {label: lbl; modules: modinfo list; base_module: lid; var_name: string}

type last_modules = (modinfo * lbl) list

type polyrecord = {name: lbl; fields: field list}

type polyrecord_map =
  (label, polyrecord, Base.String.comparator_witness) Map_intf.Map.t

let rec unique_var_name ~modules var_name_map var_name' i =
  let var_name = if i = 0 then var_name' else var_name' ^ string_of_int i in
  match Map.find var_name_map var_name with
  | Some stored_modules ->
      if List.compare cmp_modinfo stored_modules modules = 0 then
        (var_name_map, var_name)
      else unique_var_name ~modules var_name_map var_name' (i + 1)
  | None ->
      let var_name_map =
        Map.add_exn var_name_map ~key:var_name ~data:modules
      in
      (var_name_map, var_name)

let unique_field_types fields =
  List.dedup_and_sort fields ~compare:(fun field1 field2 ->
      String.compare field1.var_name field2.var_name )

let fields_pattern ~loc polyrecord =
  Pat.record ~loc
    (List.map polyrecord.fields ~f:(fun {label; _} ->
         ({txt= Lident label.txt; loc= label.loc}, Pat.var ~loc:label.loc label)
     ))
    Closed

let fields_expression ~loc polyrecord =
  Exp.record ~loc
    (List.map polyrecord.fields ~f:(fun {label; _} ->
         ( {txt= Lident label.txt; loc= label.loc}
         , Exp.ident ~loc:label.loc {txt= Lident label.txt; loc= label.loc} )
     ))
    None

let last_common_name lid1 lid2 =
  let names1 = Longident.flatten_exn lid1 in
  let names2 = Longident.flatten_exn lid2 in
  let rec last_equal prev_name names1 names2 =
    match (names1, names2) with
    | a :: names1, b :: names2 when a = b -> last_equal a names1 names2
    | _, _ -> prev_name
  in
  last_equal "unknown" names1 names2

let rec longident_of_revlist ~loc = function
  | [] -> raise_errorf ~loc "No common prefix found."
  | [a] -> Lident a
  | a :: rest -> Ldot (longident_of_revlist ~loc rest, a)

let common_prefix ~loc lid1 lid2 =
  let names1 = Longident.flatten_exn lid1 in
  let names2 = Longident.flatten_exn lid2 in
  let rec common_prefix names1 names2 =
    match (names1, names2) with
    | a :: names1, b :: names2 when a = b -> a :: common_prefix names1 names2
    | _, _ -> []
  in
  longident_of_revlist ~loc (List.rev (common_prefix names1 names2))

let is_listlike expr =
  match expr.pexp_desc with
  | Pexp_array _ | Pexp_tuple _
   |Pexp_construct
      ({txt= Lident "::"; _}, Some {pexp_desc= Pexp_tuple [_; _]; _})
   |Pexp_construct ({txt= Lident "[]"; _}, None) ->
      true
  | _ -> false

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

module Polydef = struct
  let parse_field var_name_map ({loc; txt= name}, expr) =
    let label =
      match name with
      | Lident label -> {loc; txt= label}
      | _ -> raise_errorf ~loc "Expected a bare identifier."
    in
    let modules = if is_listlike expr then parse_listlike expr else [expr] in
    let modules = List.map modules ~f:parse_to_modinfo in
    let var_name =
      match modules with
      | [ModuleName {txt= ident; _}] | [IdentName {txt= Ldot (ident, _); _}] ->
          List.hd_exn (Longident.flatten_exn ident)
      | ModuleName {txt= ident1; _} :: ModuleName {txt= ident2; _} :: _
       |ModuleName {txt= ident1; _}
        :: IdentName {txt= Ldot (ident2, _); _} :: _
       |IdentName {txt= Ldot (ident1, _); _}
        :: ModuleName {txt= ident2; _} :: _
       |IdentName {txt= Ldot (ident1, _); _}
        :: IdentName {txt= Ldot (ident2, _); _} :: _ ->
          last_common_name ident1 ident2
      | _ ->
          raise_errorf ~loc:label.loc
            "Bad formatting for module(s) in label %s." label.txt
    in
    let var_name = String.uncapitalize var_name in
    let var_name_map, var_name =
      unique_var_name var_name_map ~modules var_name 0
    in
    let base_module, modules =
      match modules with
      | [(ModuleName {txt= ident; loc} | IdentName {txt= Ldot (ident, _); loc})]
        ->
          ({txt= ident; loc}, [])
      | (ModuleName {txt= ident1; loc} | IdentName {txt= Ldot (ident1, _); loc})
        :: (ModuleName {txt= ident2; _} | IdentName {txt= Ldot (ident2, _); _})
           :: _ ->
          ({txt= common_prefix ~loc ident1 ident2; loc}, modules)
      | _ ->
          raise_errorf ~loc:label.loc
            "Expected at least one module for label %s" label.txt
    in
    (var_name_map, {label; modules; base_module; var_name})

  let build {name; fields} =
    let record_typ =
      Ptype_record
        (List.map fields ~f:(fun {label; var_name; _} ->
             let loc = label.loc in
             Type.field ~loc label (Typ.var ~loc var_name) ))
    in
    let params =
      List.map (unique_field_types fields) ~f:(fun {label; var_name; _} ->
          (Typ.var ~loc:label.loc var_name, Invariant) )
    in
    Str.type_ ~loc:name.loc Nonrecursive
      [Type.mk ~loc:name.loc ~params ~kind:record_typ name]

  let expand (map, last_modules, current_module) payload =
    match payload with
    | PStr
        [ { pstr_desc=
              Pstr_value
                ( Nonrecursive
                , [ { pvb_pat= {ppat_desc= Ppat_var name; _}
                    ; pvb_expr= {pexp_desc= Pexp_record (fields, None); _}; _
                    } ] ); _ } ] ->
        let fields =
          List.folding_map fields ~f:parse_field
            ~init:(Map.empty (module String))
        in
        let polyrecord = {name; fields} in
        if Map.mem map name.txt then
          raise_errorf ~loc:name.loc
            "A polymorphic record definition called %s already exists."
            name.txt ;
        let map = Map.add_exn map ~key:name.txt ~data:polyrecord in
        let str = build polyrecord in
        Some (str, (map, last_modules, current_module))
    | _ -> None
end

let rec longident_add lid = function
  | [] -> lid
  | name :: names -> longident_add (Ldot (lid, name)) names

module Typedef = struct
  let build ~name ~map ~polyname ~current_module polyrecord =
    let module_names = List.rev current_module in
    let modules, fields =
      List.fold_left polyrecord.fields ~init:([], [])
        ~f:(fun (modules, fields) field ->
          match field.modules with
          | [] ->
              ( (BaseModule field.base_module, field.var_name) :: modules
              , field :: fields )
          | m :: ms ->
              ( (m, field.var_name) :: modules
              , {field with modules= ms} :: fields ) )
    in
    let current_modules =
      List.rev
      @@ List.map2_exn modules fields ~f:(fun (m, _) {label; _} -> (m, label))
    in
    let fields = List.rev fields in
    let modules =
      List.dedup_and_sort modules ~compare:(fun (_, name1) (_, name2) ->
          String.compare name1 name2 )
    in
    let typs =
      List.map modules ~f:(fun (m, _) ->
          let lid =
            match m with
            | ModuleName lid -> {loc= lid.loc; txt= Ldot (lid.txt, name.txt)}
            | IdentName lid -> lid
            | BaseModule lid ->
                { loc= lid.loc
                ; txt= Ldot (longident_add lid.txt module_names, name.txt) }
          in
          Typ.constr ~loc:name.loc lid [] )
    in
    let bound_poly = Typ.constr polyname typs in
    let str = Str.type_ Nonrecursive [Type.mk ~manifest:bound_poly name] in
    let map =
      Map.update map polyrecord.name.txt ~f:(fun _ -> {polyrecord with fields})
    in
    (str, map, current_modules)

  let expand (map, _, current_module) payload =
    match payload with
    | PStr
        [ { pstr_desc=
              Pstr_value
                ( Nonrecursive
                , [ { pvb_pat= {ppat_desc= Ppat_var name; _}
                    ; pvb_expr= {pexp_desc= Pexp_ident polyname; _}; _ } ] ); _
          } ]
     |PStr
        [ { pstr_desc=
              Pstr_type
                ( _
                , [ { ptype_name= name
                    ; ptype_manifest=
                        Some {ptyp_desc= Ptyp_constr (polyname, []); _}; _ } ]
                ); _ } ] ->
        let polyrecord =
          match Map.find map (Longident.last_exn polyname.txt) with
          | Some polyrecord -> polyrecord
          | None ->
              raise_errorf ~loc:name.loc
                "Could not find the polymorphic record %s" name.txt
        in
        let str, map, last_modules =
          build ~name ~map ~polyname ~current_module polyrecord
        in
        Some (str, (map, last_modules, current_module))
    | _ -> None
end

module Snarkytyp = struct
  let build_fold ~loc ~name ~typ_mod ~fname polyrecord =
    let typ_fn f =
      Exp.ident ~loc:typ_mod.loc {txt= Ldot (typ_mod.txt, f); loc= typ_mod.loc}
    in
    List.fold_left
      (List.rev polyrecord.fields)
      ~init:
        (Exp.apply ~loc (typ_fn "return")
           [(Nolabel, fields_expression ~loc polyrecord)])
      ~f:(fun expr {base_module= base; label; _} ->
        Exp.apply (typ_fn "bind")
          [ ( Nolabel
            , Exp.apply ~loc
                (Exp.ident ~loc:fname.loc fname)
                [ ( Nolabel
                  , Exp.ident ~loc:base.loc
                      {txt= Ldot (base.txt, name.txt); loc= base.loc} )
                ; ( Nolabel
                  , Exp.ident ~loc:label.loc
                      {txt= Lident label.txt; loc= label.loc} ) ] )
          ; ( Nolabel
            , Exp.fun_ ~loc Nolabel None (Pat.var ~loc:label.loc label) expr )
          ] )

  let build ~loc ~name ~typ polyrecord =
    let typ_mod =
      match typ with
      | {txt= Ldot (typ_mod, _); loc} -> {txt= typ_mod; loc}
      | _ -> raise_errorf ~loc:typ.loc "Expected a path to Typ.t."
    in
    let typ_val m = {txt= Ldot (typ_mod.txt, m); loc= typ_mod.loc} in
    let field_pattern = fields_pattern ~loc polyrecord in
    [%stri
      let [%p Pat.var ~loc:name.loc name] =
        let store [%p field_pattern] =
          [%e
            build_fold ~loc ~name ~typ_mod:(typ_val "Store")
              ~fname:(typ_val "store") polyrecord]
        in
        let read [%p field_pattern] =
          [%e
            build_fold ~loc ~name ~typ_mod:(typ_val "Read")
              ~fname:(typ_val "read") polyrecord]
        in
        let alloc [%p field_pattern] =
          [%e
            build_fold ~loc ~name ~typ_mod:(typ_val "Alloc")
              ~fname:(typ_val "alloc") polyrecord]
        in
        let check [%p field_pattern] =
          [%e
            build_fold ~loc ~name ~typ_mod:(typ_val "Check")
              ~fname:(typ_val "check") polyrecord]
        in
        {store; read; alloc; check}]

  let expand (map, last_modules, current_module) payload =
    match payload with
    | PStr
        [ { pstr_desc=
              Pstr_eval
                ( { pexp_desc=
                      Pexp_constraint
                        ( { pexp_desc=
                              Pexp_ident {txt= Lident name; loc= name_loc}; _
                          }
                        , { ptyp_desc=
                              Ptyp_constr
                                ( typ
                                , [{ptyp_desc= Ptyp_constr (polyname, []); _}]
                                ); _ } ); _ }
                , _ )
          ; pstr_loc= loc } ] ->
        let name = {txt= name; loc= name_loc} in
        let polyrecord =
          match Map.find map (Longident.last_exn polyname.txt) with
          | Some polyrecord -> polyrecord
          | None ->
              raise_errorf ~loc:polyname.loc
                "Could not find the polymorphic record %s" name.txt
        in
        let str = build ~loc ~name ~typ polyrecord in
        Some (str, (map, last_modules, current_module))
    | _ -> None
end

module Polyfold = struct
  let rec build ~loc ~current_module ~name ~var_name ~folder last_modules =
    let module_names = List.rev current_module in
    let call (modinfo, label) =
      let f_name =
        match modinfo with
        | ModuleName {txt= ident; loc= ident_loc}
         |IdentName {txt= Ldot (ident, _); loc= ident_loc} ->
            {txt= Ldot (ident, name.txt); loc= ident_loc}
        | BaseModule {txt= ident; loc= ident_loc} ->
            { txt= Ldot (longident_add ident module_names, name.txt)
            ; loc= ident_loc }
        | _ ->
            raise_errorf ~loc
              "Malformed module name found in the previous type definition."
      in
      Exp.apply ~loc (Exp.ident ~loc f_name)
        [ ( Nolabel
          , Exp.field ~loc
              (Exp.ident ~loc:var_name.loc
                 {txt= Lident var_name.txt; loc= var_name.loc})
              {txt= Lident label.txt; loc= label.loc} ) ]
    in
    match last_modules with
    | [] ->
        raise_errorf ~loc "Could not find a type definition to use for %s."
          name.txt
    | [m] -> call m
    | m1 :: last_modules ->
        Exp.apply ~loc folder
          [ (Nolabel, call m1)
          ; ( Nolabel
            , build ~loc ~current_module ~name ~var_name ~folder last_modules
            ) ]

  let expand (map, last_modules, current_module) payload =
    match payload with
    | PStr
        [ { pstr_desc=
              Pstr_value
                ( Nonrecursive
                , [ { pvb_pat= {ppat_desc= Ppat_var name; _} as name'
                    ; pvb_expr=
                        { pexp_desc=
                            Pexp_fun
                              ( Nolabel
                              , None
                              , ({ppat_desc= Ppat_var var_name; _} as var)
                              , folder ); _ }; _ } ] )
          ; pstr_loc= loc; _ } ] ->
        let str =
          [%stri
            let [%p name'] =
             fun [%p var] ->
              [%e
                build ~loc ~current_module ~name ~var_name ~folder last_modules]]
        in
        Some (str, (map, last_modules, current_module))
    | _ -> None
end

module Polyfields = struct
  let build ~loc polyrecord =
    Str.value ~loc Nonrecursive
      (List.map polyrecord.fields ~f:(fun {label; _} ->
           let loc = label.loc in
           let label_ident = {txt= Lident label.txt; loc= label.loc} in
           let label_pat = Pat.var ~loc label in
           let destr_record = Pat.record [(label_ident, label_pat)] Open in
           Vb.mk ~loc label_pat
             (Exp.fun_ ~loc Nolabel None destr_record
                (Exp.ident ~loc label_ident)) ))

  let expand (map, last_modules, current_module) payload =
    match payload with
    | PStr
        [ { pstr_desc= Pstr_eval ({pexp_desc= Pexp_ident polyname; _}, _)
          ; pstr_loc= loc; _ } ] ->
        let polyrecord =
          match Map.find map (Longident.last_exn polyname.txt) with
          | Some polyrecord -> polyrecord
          | None ->
              raise_errorf ~loc "Could not find the polymorphic record %s"
                (Longident.last_exn polyname.txt)
        in
        let str = build ~loc polyrecord in
        Some (str, (map, last_modules, current_module))
    | _ -> None
end

let snarky_module_map =
  object
    inherit
      [polyrecord_map * last_modules * string list] Ast_traverse.fold_map as super

    method! structure_item str acc =
      let or_default v =
        match v with Some v -> v | None -> super#structure_item str acc
      in
      match str.pstr_desc with
      | Pstr_extension (({txt= name; _}, payload), _) -> (
        match name with
        | "polydef" -> or_default (Polydef.expand acc payload)
        | "poly" -> or_default (Typedef.expand acc payload)
        | "snarkytyp" -> or_default (Snarkytyp.expand acc payload)
        | "polyfold" -> or_default (Polyfold.expand acc payload)
        | "polyfields" -> or_default (Polyfields.expand acc payload)
        | _ -> super#structure_item str acc )
      | _ -> super#structure_item str acc

    method! module_binding bind (map, last_modules, current_module') =
      let current_module = bind.pmb_name.txt :: current_module' in
      let mb, (map, last_modules, _) =
        super#module_binding bind (map, last_modules, current_module)
      in
      (mb, (map, last_modules, current_module'))
  end

let include_ ~loc ?(attr = []) mod_ =
  Str.include_ ~loc {pincl_loc= loc; pincl_attributes= attr; pincl_mod= mod_}

let snarky_module ~loc ~path:_ payload =
  match payload with
  | PStr structure ->
      let structure, _ =
        snarky_module_map#structure structure
          (Map.empty (module String), [], [])
      in
      include_ ~loc (Mod.structure ~loc structure)
  | _ -> raise_errorf ~loc "Expected [%%snarky_module] to contain a structure."

let ext =
  Extension.declare "snarky_module" Extension.Context.structure_item
    Ast_pattern.__ snarky_module

let main () =
  Driver.register_transformation "snarky_module"
    ~rules:[Context_free.Rule.extension ext]
