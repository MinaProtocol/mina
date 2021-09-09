open Base
open Ppxlib

let deriver_name = "to_representatives"

let mangle ~suffix name =
  if String.equal name "t" then suffix else name ^ "_" ^ suffix

let mangle_lid ~suffix lid =
  match lid with
  | Lident name ->
      Lident (mangle ~suffix name)
  | Ldot (lid, name) ->
      Ldot (lid, mangle ~suffix name)
  | Lapply _ ->
      assert false

let mk_lid name = Loc.make ~loc:name.loc (Longident.Lident name.txt)

let constr_of_decl ~loc decl =
  Ast_builder.Default.ptyp_constr ~loc (mk_lid decl.ptype_name)
    (List.map ~f:fst decl.ptype_params)

let is_builtin = function
  | "unit" | "bool" | "int" | "string" | "char" | "bytes" ->
      true
  | "int32" | "int64" | "nativeint" ->
      true
  | _ ->
      false

let is_builtin_with_arg = function
  | "list" | "option" | "array" ->
      true
  | _ ->
      false

let mk_builtin ~loc name =
  Ast_builder.Default.pexp_ident ~loc
    (Loc.make ~loc
       (Ldot
          ( Lident "Ppx_representatives_runtime"
          , mangle ~suffix:deriver_name name )))

(* The way that we expand representatives below makes it extremely easy to blow
   the stack if we're not tail-recursive. All generated list iterators should
   use the [rev_*] versions of functions when their non-reversed alternatives
   are not tail recursive.
*)
let rec core_type ~loc (typ : core_type) : expression =
  let open Ast_builder.Default in
  match typ.ptyp_desc with
  | Ptyp_any ->
      Location.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive %s for anonymous type variables" deriver_name
  | Ptyp_var name ->
      (* Names for type variables should be placed in context at the type
        declaration level.
     *)
      evar ~loc name
  | Ptyp_arrow (label, _, _) ->
      [%expr
        lazy
          [ [%e
              pexp_fun ~loc label None
                [%pat? _]
                [%expr
                  Stdlib.failwith
                    [%e
                      estring ~loc
                        (Stdlib.Format.asprintf
                           "%s: Illegal call to dummy functional value \
                            defined by %a"
                           deriver_name Ocaml_common.Location.print_loc
                           typ.ptyp_loc)]]] ]]
  | Ptyp_tuple typs ->
      let exprs = List.map ~f:(core_type ~loc) typs in
      let mk_name i =
        "__" ^ deriver_name ^ "__internal_name_" ^ Int.to_string i
      in
      let result =
        [%expr
          [ [%e
              pexp_tuple ~loc
                (List.mapi exprs ~f:(fun i _ -> evar ~loc (mk_name i)))] ]]
      in
      (* We map over each alternative in the tuple to get every possible
         combination.
      *)
      [%expr
        lazy
          [%e
            List.foldi ~init:result exprs ~f:(fun i expr arg ->
                [%expr
                  Ppx_representatives_runtime.Util.rev_concat
                    (Stdlib.List.rev_map
                       (fun [%p pvar ~loc (mk_name i)] -> [%e expr])
                       (Stdlib.Lazy.force [%e arg]))] )]]
  | Ptyp_constr ({txt= Lident name; _}, []) when is_builtin name ->
      mk_builtin ~loc name
  | Ptyp_constr ({txt= Lident name; _}, [_]) when is_builtin_with_arg name ->
      [%expr [%e mk_builtin ~loc name] ()]
  | Ptyp_constr (lid, typs) ->
      let exprs = List.map ~f:(core_type ~loc) typs in
      pexp_apply ~loc
        (pexp_ident ~loc (Located.map (mangle_lid ~suffix:deriver_name) lid))
        (List.map exprs ~f:(fun e -> (Nolabel, e)))
  | Ptyp_object _ ->
      Location.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive %s for object types" deriver_name
  | Ptyp_class _ ->
      Location.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive %s for class types" deriver_name
  | Ptyp_alias _ ->
      (* Really we should bubble a let definition for the alias out to the
         type, but we don't need this currently, so it's not worth the
         complexity.
      *)
      Location.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive %s for type aliases" deriver_name
  | Ptyp_variant (rows, _, _) ->
      (* Could throw an error if it is open, but the alias failure above
         prevents this from happening in type definitions anyway.
      *)
      [%expr
        lazy
          (Ppx_representatives_runtime.Util.rev_concat
             [%e
               elist ~loc
                 (List.rev_map rows ~f:(function
                   | Rtag (name, _, _, []) ->
                       [%expr [[%e pexp_variant ~loc name.txt None]]]
                   | Rtag (name, _, _, [typ]) ->
                       [%expr
                         Stdlib.List.rev_map
                           (fun e ->
                             [%e pexp_variant ~loc name.txt (Some [%expr e])]
                             )
                           (Stdlib.Lazy.force [%e core_type ~loc typ])]
                   | Rtag _ ->
                       Location.raise_errorf ~loc:typ.ptyp_loc
                         "Cannot derive %s for variant constructors with \
                          different type arguments for the same constructor"
                         deriver_name
                   | Rinherit typ' ->
                       [%expr
                         Stdlib.List.rev
                           (Stdlib.Lazy.force
                              (* Coerce here, because the inherited type may be a
                                 strict subtype.
                              *)
                              ([%e core_type ~loc typ'] :> [%t typ] list lazy_t))] ))])]
  | Ptyp_poly (vars, typ) ->
      (* Inject dummy representatives into the environment so that they can
         resolve.
      *)
      [%expr
        lazy
          [%e
            List.fold ~init:(core_type ~loc typ) vars ~f:(fun expr var ->
                [%expr
                  let [%p pvar ~loc var.txt] =
                    Stdlib.Lazy.from_fun (fun () -> failwith "Unknown type")
                  in
                  [%e expr]] )]]
  | Ptyp_package _ ->
      Location.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive %s for packaged modules" deriver_name
  | Ptyp_extension _ ->
      Location.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive %s for un-expanded extensions" deriver_name

let record_decl ~loc (fields : label_declaration list) : expression =
  let open Ast_builder.Default in
  [%expr
    lazy
      [%e
        List.fold fields
          ~f:(fun expr field ->
            [%expr
              Ppx_representatives_runtime.Util.rev_concat
                (Stdlib.List.rev_map
                   (fun [%p pvar ~loc field.pld_name.txt] -> [%e expr])
                   (Lazy.force [%e core_type ~loc field.pld_type]))] )
          ~init:
            [%expr
              [ [%e
                  pexp_record ~loc
                    (List.map fields ~f:(fun field ->
                         (mk_lid field.pld_name, evar ~loc field.pld_name.txt)
                     ))
                    None] ]]]]

let str_decl ~loc (decl : type_declaration) : structure_item =
  let open Ast_builder.Default in
  let binding expr =
    [%stri
      let ([%p pvar ~loc (mangle ~suffix:deriver_name decl.ptype_name.txt)] :
            [%t
              List.fold_right decl.ptype_params
                ~f:(fun (param, _) typ ->
                  [%type: [%t param] list lazy_t -> [%t typ]] )
                ~init:[%type: [%t constr_of_decl ~loc decl] list lazy_t]]) =
        [%e
          List.fold_right decl.ptype_params ~init:expr
            ~f:(fun (param, _) expr ->
              let pat =
                match param.ptyp_desc with
                | Ptyp_any ->
                    [%pat? _]
                | Ptyp_var name ->
                    pvar ~loc name
                | _ ->
                    Location.raise_errorf ~loc:param.ptyp_loc
                      "Expected a type variable or _"
              in
              [%expr fun [%p pat] -> [%e expr]] )]]
  in
  match decl with
  | {ptype_kind= Ptype_variant constrs; _} ->
      binding
        [%expr
          lazy
            (Ppx_representatives_runtime.Util.rev_concat
               [%e
                 elist ~loc
                   (List.rev_map constrs ~f:(fun constr ->
                        let args =
                          match constr.pcd_args with
                          | Pcstr_tuple [] ->
                              None
                          | Pcstr_tuple [typ] ->
                              Some (core_type ~loc typ)
                          | Pcstr_tuple typs ->
                              Some (core_type ~loc (ptyp_tuple ~loc typs))
                          | Pcstr_record fields ->
                              Some (record_decl ~loc fields)
                        in
                        match args with
                        | None ->
                            [%expr
                              [ [%e
                                  pexp_construct ~loc (mk_lid constr.pcd_name)
                                    None] ]]
                        | Some arg ->
                            [%expr
                              Stdlib.List.rev_map
                                (fun x ->
                                  [%e
                                    pexp_construct ~loc
                                      (mk_lid constr.pcd_name)
                                      (Some [%expr x])] )
                                (Stdlib.Lazy.force [%e arg])] ))])]
  | {ptype_kind= Ptype_abstract; ptype_manifest= Some typ; _} ->
      binding (core_type ~loc typ)
  | {ptype_kind= Ptype_record fields; _} ->
      binding (record_decl ~loc fields)
  | _ ->
      Location.raise_errorf ~loc "Cannot derive %s for this type" deriver_name

let sig_decl ~loc (decl : type_declaration) : signature_item =
  let open Ast_builder.Default in
  psig_value ~loc
  @@ value_description ~loc ~prim:[]
       ~name:
         (Located.mk ~loc (mangle ~suffix:deriver_name decl.ptype_name.txt))
       ~type_:
         (List.fold_right decl.ptype_params
            ~f:(fun (param, _) typ ->
              [%type: [%t param] list lazy_t -> [%t typ]] )
            ~init:[%type: [%t constr_of_decl ~loc decl] list lazy_t])

let str_type_decl ~loc ~path:_ (_rec_flag, decls) : structure =
  List.map ~f:(str_decl ~loc) decls

let sig_type_decl ~loc ~path:_ (_rec_flag, decls) : signature =
  List.map ~f:(sig_decl ~loc) decls

let deriver =
  Deriving.add
    ~str_type_decl:(Deriving.Generator.make_noarg str_type_decl)
    ~sig_type_decl:(Deriving.Generator.make_noarg sig_type_decl)
    deriver_name
