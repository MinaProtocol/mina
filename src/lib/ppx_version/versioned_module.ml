open Core_kernel
open Ppxlib
open Versioned_util

let no_toplevel_latest_type = ref false

let with_all_version_tags = "with_all_version_tags"

let with_all_version_tags_module = String.capitalize with_all_version_tags

let with_top_version_tag = "with_top_version_tag"

let with_top_version_tag_module = String.capitalize with_top_version_tag

let with_versioned_json = "with_versioned_json"

let no_toplevel_latest_type_str = "no_toplevel_latest_type"

let ty_decl_to_string =
  let buf = Buffer.create 2048 in
  let formatter =
    Versioned_util.diff_formatter @@ Format.formatter_of_buffer buf
  in
  (* filter attributes from types *)
  let filter_attrs =
    object (self)
      inherit Ast_traverse.map

      method! core_type ty =
        { ty with
          ptyp_desc = self#core_type_desc ty.ptyp_desc
        ; ptyp_attributes = []
        }

      method! core_type_desc ty_desc =
        match ty_desc with
        | Ptyp_arrow (arg, ty_from, ty_to) ->
            Ptyp_arrow (arg, self#core_type ty_from, self#core_type ty_to)
        | Ptyp_tuple tys ->
            Ptyp_tuple (List.map tys ~f:self#core_type)
        | Ptyp_constr (loc, tys) ->
            Ptyp_constr (loc, List.map tys ~f:self#core_type)
        | Ptyp_class (loc, tys) ->
            Ptyp_class (loc, List.map tys ~f:self#core_type)
        | Ptyp_alias (ty, label) ->
            Ptyp_alias (self#core_type ty, label)
        | Ptyp_object (fields, closed) ->
            let fields' =
              List.map fields ~f:(fun field ->
                  let pof_desc =
                    match field.pof_desc with
                    | Otag (label, ty) ->
                        Otag (label, self#core_type ty)
                    | Oinherit ty ->
                        Oinherit (self#core_type ty)
                  in
                  let pof_attributes = [] in
                  { field with pof_desc; pof_attributes } )
            in
            Ptyp_object (fields', closed)
        | Ptyp_poly (parms, ty) ->
            Ptyp_poly (parms, self#core_type ty)
        | Ptyp_package (mod_name, with_types) ->
            let with_types' =
              List.map with_types ~f:(fun (loc, ty) ->
                  (loc, self#core_type ty) )
            in
            Ptyp_package (mod_name, with_types')
        | Ptyp_variant (fields, closed, labels) ->
            let fields' =
              List.map fields ~f:(fun field ->
                  let prf_desc =
                    match field.prf_desc with
                    | Rtag (label, const, tys) ->
                        Rtag (label, const, List.map tys ~f:self#core_type)
                    | Rinherit ty ->
                        Rinherit (self#core_type ty)
                  in
                  { field with prf_desc; prf_attributes = [] } )
            in
            Ptyp_variant (fields', closed, labels)
        | Ptyp_any | Ptyp_var _ ->
            ty_desc
        | Ptyp_extension _ ->
            (* punting on very unlikely case *)
            ty_desc

      method! type_kind =
        function
        | Ptype_abstract ->
            Ptype_abstract
        | Ptype_variant ctors ->
            let ctors' =
              List.map ctors ~f:(fun ctor ->
                  let pcd_args =
                    match ctor.pcd_args with
                    | Pcstr_tuple tys ->
                        Pcstr_tuple (List.map tys ~f:self#core_type)
                    | Pcstr_record labels ->
                        Pcstr_record
                          (List.map labels ~f:(fun label ->
                               { label with
                                 pld_type = self#core_type label.pld_type
                               ; pld_attributes = []
                               } ) )
                  in
                  let pcd_res = Option.map ctor.pcd_res ~f:self#core_type in
                  { ctor with pcd_args; pcd_res; pcd_attributes = [] } )
            in
            Ptype_variant ctors'
        | Ptype_record labels ->
            Ptype_record
              (List.map labels ~f:(fun label ->
                   { label with
                     pld_type = self#core_type label.pld_type
                   ; pld_attributes = []
                   } ) )
        | Ptype_open ->
            Ptype_open

      method! type_declaration ty_decl =
        let ptype_params =
          List.map ty_decl.ptype_params ~f:(fun (ty, var_inj) ->
              (self#core_type ty, var_inj) )
        in
        let ptype_manifest =
          Option.map ty_decl.ptype_manifest ~f:self#core_type
        in
        let ptype_kind = self#type_kind ty_decl.ptype_kind in
        { ty_decl with
          ptype_params
        ; ptype_manifest
        ; ptype_cstrs = []
        ; ptype_kind
        ; ptype_attributes = []
        }
    end
  in
  let filter_type_manifests type_decl =
    match type_decl.ptype_kind with
    | Ptype_abstract | Ptype_open ->
        type_decl
    | Ptype_variant _ | Ptype_record _ ->
        { type_decl with ptype_manifest = None }
  in
  fun ty_decl ->
    Buffer.clear buf ;
    let ty_decl' =
      ty_decl |> filter_attrs#type_declaration |> filter_type_manifests
    in
    Pprintast.type_declaration formatter ty_decl' ;
    Format.pp_print_flush formatter () ;
    let s = Buffer.contents buf in
    (* formatter replaces initial newline with space, removed here *)
    String.sub s ~pos:1 ~len:(String.length s - 1)

(* option to `deriving version' *)
type version_option = No_version_option | Binable | Rpc [@@deriving equal]

let create_attr ~loc attr_name attr_payload =
  { attr_name; attr_payload; attr_loc = loc }

let modify_attr_payload attr payload = { attr with attr_payload = payload }

let rec add_deriving ~loc ~version_option attributes : attributes =
  let (module Ast_builder) = Ast_builder.make loc in
  let payload idents =
    let payload = Ast_builder.(pstr_eval (pexp_tuple idents) []) in
    PStr [ payload ]
  in
  let version_expr =
    match version_option with
    | No_version_option ->
        [%expr version]
    | Binable ->
        [%expr version { binable }]
    | Rpc ->
        [%expr version { rpc }]
  in
  match attributes with
  | [] ->
      let attr_name = mk_loc ~loc "deriving" in
      let attr_payload =
        match version_option with
        | No_version_option ->
            payload [ [%expr bin_io]; version_expr ]
        | Binable ->
            payload [ version_expr ]
        | Rpc ->
            payload [ [%expr bin_io]; version_expr ]
      in
      [ create_attr ~loc attr_name attr_payload ]
  | attr :: attributes -> (
      let idents =
        Ast_pattern.(
          attribute ~name:(string "deriving") ~payload:(single_expr_payload __))
      in
      match parse_opt idents loc attr (fun l -> Some l) with
      | None ->
          attr :: add_deriving ~loc ~version_option attributes
      | Some args ->
          (* Can't use [Ast_pattern] here, because [alt] doesn't suppress the
             errors raised from the [pexp_*] patterns..
          *)
          let args =
            match args.pexp_desc with Pexp_tuple args -> args | _ -> [ args ]
          in
          let special_version =
            Ast_pattern.(pexp_apply (pexp_ident (lident (string "version"))) __)
          in
          let has_version =
            List.exists args ~f:(fun arg ->
                Option.is_some
                @@ parse_opt special_version loc arg (fun _ -> Some ()) )
          in
          let needs_bin_io =
            match version_option with
            | No_version_option ->
                true
            | Binable ->
                false
            | Rpc ->
                true
          in
          let extra_payload_args =
            match (has_version, needs_bin_io) with
            | false, false ->
                [ version_expr ]
            | false, true ->
                [ [%expr bin_io]; version_expr ]
            | true, false ->
                []
            | true, true ->
                [ [%expr bin_io] ]
          in
          modify_attr_payload attr (payload (extra_payload_args @ args))
          :: attributes )

let erase_stable_versions =
  object
    inherit Ast_traverse.map as super

    method! core_type ty =
      match ty.ptyp_desc with
      | Ptyp_constr
          ({ txt = Ldot (Ldot (Ldot (lid, "Stable"), vn), "t"); loc }, typs)
        when try
               validate_module_version vn loc ;
               true
             with _ -> false ->
          (* Erase [.Stable.Vn.t] to [.t] *)
          let ty =
            { ty with
              ptyp_desc = Ptyp_constr ({ txt = Ldot (lid, "t"); loc }, typs)
            }
          in
          super#core_type ty
      | _ ->
          super#core_type ty

    method! type_declaration ty_decl =
      let ty_decl = super#type_declaration ty_decl in
      let ptype_attributes : attributes =
        List.filter_map ty_decl.ptype_attributes
          ~f:(fun ({ attr_name; attr_payload = payload; attr_loc } as attr) ->
            if String.equal attr_name.txt "deriving" then
              let remove_derivers = [| "bin_io"; "version" |] in
              match payload with
              | PStr
                  [ ( { pstr_desc =
                          Pstr_eval
                            (({ pexp_desc = Pexp_tuple exprs; _ } as expr), _)
                      ; _
                      } as stri )
                  ] -> (
                  let exprs =
                    List.filter exprs ~f:(function
                      | { pexp_desc = Pexp_ident { txt = Lident name; _ }; _ }
                      | { pexp_desc =
                            Pexp_apply
                              ( { pexp_desc = Pexp_ident { txt = Lident name; _ }
                                ; _
                                }
                              , _ )
                        ; _
                        }
                        when Array.mem ~equal:String.equal remove_derivers name
                        ->
                          false
                      | _ ->
                          true )
                  in
                  match exprs with
                  | [] ->
                      None
                  | [ e ] ->
                      Some
                        { attr_name
                        ; attr_payload =
                            PStr [ { stri with pstr_desc = Pstr_eval (e, []) } ]
                        ; attr_loc
                        }
                  | es ->
                      Some
                        { attr_name
                        ; attr_payload =
                            PStr
                              [ { stri with
                                  pstr_desc =
                                    Pstr_eval
                                      ( { expr with pexp_desc = Pexp_tuple es }
                                      , [] )
                                }
                              ]
                        ; attr_loc
                        } )
              | PStr
                  [ { pstr_desc =
                        Pstr_eval
                          ( { pexp_desc =
                                ( Pexp_ident { txt = Lident name; _ }
                                | Pexp_apply
                                    ( { pexp_desc =
                                          Pexp_ident { txt = Lident name; _ }
                                      ; _
                                      }
                                    , _ ) )
                            ; _
                            }
                          , _ )
                    ; _
                    }
                  ]
                when Array.mem ~equal:String.equal remove_derivers name ->
                  None
              | _ ->
                  Some attr
            else Some attr )
      in
      { ty_decl with
        ptype_attributes
      ; ptype_manifest =
          Some
            (Ast_helper.Typ.constr ~loc:ty_decl.ptype_loc
               { Location.txt = Longident.parse "Stable.Latest.t"
               ; loc = ty_decl.ptype_loc
               }
               (List.map ~f:fst ty_decl.ptype_params) )
      }
  end

let mk_all_version_tags_type_decl =
  object (self)
    inherit Ast_traverse.map as super

    method! core_type typ =
      match typ.ptyp_desc with
      | Ptyp_constr
          ({ txt = Ldot (Ldot (Ldot (lid, "Stable"), vn), "t"); loc }, typs)
        when try
               validate_module_version vn loc ;
               true
             with _ -> false ->
          (* Change [.Stable.Vn.t] to [.Stable.Vn.With_all_version_tags.t] *)
          let typ =
            { typ with
              ptyp_desc =
                Ptyp_constr
                  ( { txt =
                        Ldot
                          ( Ldot
                              ( Ldot (Ldot (lid, "Stable"), vn)
                              , with_all_version_tags_module )
                          , "t" )
                    ; loc
                    }
                  , typs )
            }
          in
          super#core_type typ
      | _ ->
          super#core_type typ

    method! type_declaration type_decl =
      if String.equal type_decl.ptype_name.txt "t" then
        let loc = type_decl.ptype_name.loc in
        { (super#type_declaration type_decl) with
          ptype_name = { txt = "typ"; loc }
        ; ptype_manifest =
            (* type typ = t = ... *)
            ( match type_decl.ptype_manifest with
            | Some
                ( { ptyp_desc =
                      Ptyp_constr
                        ( { txt = Ldot (Ldot (Ldot (lid, "Stable"), vn), "t")
                          ; loc
                          }
                        , params )
                  ; _
                  } as manifest_ty ) ->
                (* type typ = Foo.Stable.Vn.t becomes type typ = Foo.Stable.Vn.With_all_version_tags.t *)
                Some
                  { manifest_ty with
                    ptyp_desc =
                      Ptyp_constr
                        ( { txt =
                              Ldot
                                ( Ldot
                                    ( Ldot (Ldot (lid, "Stable"), vn)
                                    , with_all_version_tags_module )
                                , "t" )
                          ; loc
                          }
                        , List.map params ~f:(fun param -> self#core_type param)
                        )
                  }
            | Some m ->
                Some m
            | None ->
                let params =
                  List.map type_decl.ptype_params ~f:(fun (ty, _invariance) ->
                      ty )
                in
                Some
                  { ptyp_desc = Ptyp_constr ({ txt = Lident "t"; loc }, params)
                  ; ptyp_loc = loc
                  ; ptyp_loc_stack = []
                  ; ptyp_attributes = []
                  } )
        ; ptype_attributes =
            (let (module Ast_builder) = Ast_builder.make loc in
             let open Ast_builder in
             [ create_attr ~loc (Located.mk "deriving") (PStr [ [%stri bin_io] ])
             ] )
        }
      else type_decl
  end

let version_type ~version_option ~all_version_tagged ~top_version_tag
    ~json_version_tag ~modl_stri version stri =
  let loc = stri.pstr_loc in
  let (module Ast_builder) = Ast_builder.make loc in
  let find_t_stri stri =
    let is_t_stri stri =
      match stri.pstr_desc with
      | Pstr_type
          ( _rec_flag
          , [ { ptype_name = { txt = "t"; _ }; ptype_private = Public; _ } ] )
        ->
          true
      | _ ->
          false
    in
    if is_t_stri stri then stri
    else
      match stri.pstr_desc with
      | Pstr_module { pmb_expr = { pmod_desc = Pmod_structure str; _ }; _ } -> (
          match List.find str ~f:is_t_stri with
          | Some stri ->
              stri
          | None ->
              Location.raise_errorf ~loc:stri.pstr_loc
                "Expected module to contain a type t." )
      | _ ->
          Location.raise_errorf ~loc:stri.pstr_loc
            "Expected a module containing a type t."
  in
  let t_stri = find_t_stri stri in
  let find_include_binable_stri stri =
    let is_include_binable_stri stri =
      match stri.pstr_desc with
      | Pstr_include
          { pincl_mod =
              { pmod_desc =
                  Pmod_apply
                    ( { pmod_desc =
                          Pmod_apply
                            ( { pmod_desc =
                                  Pmod_ident
                                    { txt = Ldot (Lident "Binable", of_binable)
                                    ; _
                                    }
                              ; _
                              }
                            , { pmod_desc = Pmod_ident _; _ } )
                      ; _
                      }
                    , _ )
              ; _
              }
          ; _
          }
        when List.mem
               [ "Of_binable"
               ; "Of_binable_without_uuid"
               ; "Of_binable1"
               ; "Of_binable1_without_uuid"
               ; "Of_binable2"
               ; "Of_binable2_without_uuid"
               ; "Of_binable3"
               ; "Of_binable3_without_uuid"
               ]
               of_binable ~equal:String.equal ->
          true
      | _ ->
          false
    in
    if is_include_binable_stri stri then stri
    else
      match stri.pstr_desc with
      | Pstr_module { pmb_expr = { pmod_desc = Pmod_structure str; _ }; _ } -> (
          match List.find str ~f:is_include_binable_stri with
          | Some stri ->
              stri
          | None ->
              Location.raise_errorf ~loc:stri.pstr_loc
                "Expected module to include a Binable functor application." )
      | _ ->
          Location.raise_errorf ~loc:stri.pstr_loc
            "Expected a module including a Binable functor application."
  in
  let make_all_tags_binable_include =
    object
      inherit Ast_traverse.map

      method! longident longident =
        match longident with
        | Ldot (Ldot (lid, "Stable"), vn)
          when try
                 validate_module_version vn loc ;
                 true
               with _ -> false ->
            Ldot (Ldot (Ldot (lid, "Stable"), vn), with_all_version_tags_module)
        | _ ->
            longident
    end
  in
  let t, t_is_unboxed, params =
    let subst_type t_stri =
      (* NOTE: Can't use [Ast_pattern] here; it rejects attributes attached to
         types..
      *)
      match t_stri.pstr_desc with
      | Pstr_type
          ( rec_flag
          , [ ( { ptype_name = { txt = "t"; _ }
                ; ptype_private = Public
                ; ptype_attributes
                ; _
                } as typ )
            ] ) ->
          let params = typ.ptype_params in
          let typ =
            { typ with
              ptype_attributes =
                add_deriving ~loc:typ.ptype_loc ~version_option
                  typ.ptype_attributes
            }
          in
          let t = { stri with pstr_desc = Pstr_type (rec_flag, [ typ ]) } in
          let is_unboxed =
            List.exists ptype_attributes
              ~f:(fun { attr_name = { txt; _ }; _ } ->
                String.equal txt "unboxed" )
          in
          (t, is_unboxed, params)
      | _ ->
          (* should be unreachable *)
          (* TODO: Handle rpc types. *)
          Location.raise_errorf ~loc:stri.pstr_loc
            "Expected a single public type t."
    in
    subst_type t_stri
  in
  let empty_params = List.is_empty params in
  let extra_stris =
    let arg_names = List.mapi params ~f:(fun i _ -> sprintf "x%i" i) in
    let apply_args =
      let args =
        List.map arg_names ~f:(fun x ->
            (Nolabel, Ast_builder.(pexp_ident (Located.lident x))) )
      in
      match args with
      | [] ->
          fun ?f:_ e -> e
      | _ ->
          fun ?f e ->
            let args =
              match f with
              | None ->
                  args
              | Some f ->
                  List.map args ~f:(fun (lbl, x) -> (lbl, f x))
            in
            Ast_builder.(pexp_apply e args)
    in
    let fun_args e =
      List.fold_right arg_names ~init:e ~f:(fun name e ->
          Ast_builder.(pexp_fun Nolabel None (ppat_var (Located.mk name)) e) )
    in
    let mk_field fld e =
      Ast_builder.(
        pexp_field e
          (Located.mk (Ldot (Ldot (Lident "Bin_prot", "Type_class"), fld))))
    in
    let open Ast_builder in
    let yojson_tag_shadows =
      if not json_version_tag then []
      else
        [%str
          let to_yojson item =
            `Assoc
              [ ("version", `Int [%e eint version]); ("data", to_yojson item) ]

          let of_yojson json =
            match json with
            | `Assoc [ ("version", `Int n); ("data", data_json) ] ->
                if n = [%e eint version] then of_yojson data_json
                else
                  Ppx_deriving_yojson_runtime.Result.Error
                    (Core_kernel.sprintf "In JSON, expected version %d, got %d"
                       [%e eint version] n )
            | _ ->
                Ppx_deriving_yojson_runtime.Result.Error
                  "Expected versioned JSON"

          let (_ : _) = (to_yojson, of_yojson)]
    in
    let deriving_bin_io =
      lazy (create_attr ~loc (Located.mk "deriving") (PStr [ [%stri bin_io] ]))
    in
    let unboxed_attr =
      lazy (create_attr ~loc (Located.mk "unboxed") (PStr []))
    in
    let make_tag_module ?bin_io_include typ_decl mod_name =
      (* if bin_io_include is given, then we use that to generate the
         bin_io functions, instead of using `deriving bin_io` on `typ`
      *)
      let t_tagged =
        (* type `t_tagged` is a record containing a version and an instance of `typ`,
           when serializing, take a `typ`, add the version number
           when deserializing, return just the `typ` part
        *)
        let ty_decl =
          type_declaration ~name:(Located.mk "t_tagged") ~params ~cstrs:[]
            ~private_:Public ~manifest:None
            ~kind:
              (Ptype_record
                 [ label_declaration ~name:(Located.mk "version")
                     ~mutable_:Immutable
                     ~type_:(ptyp_constr (Located.lident "int") [])
                 ; label_declaration ~name:(Located.mk "t") ~mutable_:Immutable
                     ~type_:
                       (ptyp_constr (Located.lident "typ")
                          (List.map ~f:fst params) )
                 ] )
        in
        { ty_decl with ptype_attributes = [ Lazy.force deriving_bin_io ] }
      in
      let t =
        (* type `t` is equal to `typ`, but serialized/deserialized as `t_tagged` *)
        type_declaration ~name:(Located.mk "t") ~params ~cstrs:[]
          ~private_:Public
          ~manifest:
            (Some (ptyp_constr (Located.lident "typ") (List.map ~f:fst params)))
          ~kind:Ptype_abstract
      in
      let create = [%stri let create t = { t; version = [%e eint version] }] in
      let bin_io_t =
        [ [%stri
            let bin_read_t =
              [%e
                fun_args
                  [%expr
                    fun buf ~pos_ref ->
                      let { version = read_version; t } =
                        [%e apply_args [%expr bin_read_t_tagged]] buf ~pos_ref
                      in
                      (* sanity check *)
                      if
                        not
                          (Core_kernel.Int.equal read_version [%e eint version])
                      then
                        failwith
                          (Core_kernel.sprintf
                             "bin_read_t: version read %d does not match \
                              expected version %d"
                             read_version [%e eint version] ) ;
                      t]]]
        ; [%stri
            let __bin_read_t__ =
              [%e
                fun_args
                  [%expr
                    fun buf ~pos_ref i ->
                      let { version = read_version; t } =
                        [%e apply_args [%expr __bin_read_t_tagged__]]
                          buf ~pos_ref i
                      in
                      (* sanity check *)
                      if
                        not
                          (Core_kernel.Int.equal read_version [%e eint version])
                      then
                        failwith
                          (Core_kernel.sprintf
                             "__bin_read_t__: version read %d does not match \
                              expected version %d"
                             read_version version ) ;
                      t]]]
        ; [%stri
            let bin_reader_t =
              [%e
                fun_args
                  [%expr
                    { Bin_prot.Type_class.read =
                        [%e apply_args ~f:(mk_field "read") [%expr bin_read_t]]
                    ; vtag_read =
                        [%e
                          apply_args ~f:(mk_field "read") [%expr __bin_read_t__]]
                    }]]]
        ; [%stri
            let bin_size_t =
              [%e
                fun_args
                  [%expr
                    fun t ->
                      create t |> [%e apply_args [%expr bin_size_t_tagged]]]]]
        ; [%stri let bin_shape_t = bin_shape_t_tagged]
        ; [%stri
            let bin_write_t =
              [%e
                fun_args
                  [%expr
                    fun buf ~pos t ->
                      create t
                      |> [%e apply_args [%expr bin_write_t_tagged]] buf ~pos]]]
        ; [%stri
            let bin_writer_t =
              [%e
                fun_args
                  [%expr
                    { Bin_prot.Type_class.size =
                        [%e apply_args ~f:(mk_field "size") [%expr bin_size_t]]
                    ; write =
                        [%e
                          apply_args ~f:(mk_field "write") [%expr bin_write_t]]
                    }]]]
        ; [%stri
            let bin_t =
              [%e
                fun_args
                  [%expr
                    { Bin_prot.Type_class.shape =
                        [%e
                          apply_args ~f:(mk_field "shape") [%expr bin_shape_t]]
                    ; writer =
                        [%e
                          apply_args ~f:(mk_field "writer") [%expr bin_writer_t]]
                    ; reader =
                        [%e
                          apply_args ~f:(mk_field "reader") [%expr bin_reader_t]]
                    }]]]
        ; [%stri
            let (_ : _) =
              ( bin_read_t
              , __bin_read_t__
              , bin_reader_t
              , bin_size_t
              , bin_shape_t
              , bin_write_t
              , bin_writer_t
              , bin_t )]
        ]
      in
      let include_str =
        match bin_io_include with
        | Some stri ->
            (* the include generates bin_io functions for `t`, but we need them
               for `typ`
            *)
            stri
            :: [%str
                 let bin_read_typ = bin_read_t

                 let __bin_read_typ__ = __bin_read_t__

                 let bin_reader_typ = bin_reader_t

                 let bin_size_typ = bin_size_t

                 let bin_shape_typ = bin_shape_t

                 let bin_write_typ = bin_write_t

                 let bin_writer_typ = bin_writer_t

                 let bin_typ = bin_t

                 let (_ : _) =
                   ( bin_read_typ
                   , __bin_read_typ__
                   , bin_reader_typ
                   , bin_size_typ
                   , bin_shape_typ
                   , bin_write_typ
                   , bin_writer_typ
                   , bin_typ )]
        | None ->
            []
      in
      [ pstr_module
          (module_binding
             ~name:(some_loc (Located.mk mod_name))
             ~expr:
               (pmod_structure
                  ( pstr_type Recursive [ typ_decl ]
                  :: ( include_str
                     @ [ pstr_type Recursive [ t_tagged ]
                       ; pstr_type Recursive [ t ]
                       ]
                     @ (create :: bin_io_t) ) ) ) )
      ]
    in
    let all_version_tag_modules =
      if not all_version_tagged then []
      else if equal_version_option version_option Binable then
        (* the With_all_version_tags module contains the same Binable functor invocation,
           except the serializing argument is itself an With_all_version_tags module

           if we had

           include Binable.Of_binable_without_uuid
             (M.Stable.V1)
             (struct ... end)

           we generate

           include Binable.Of_binable_without_uuid
             (M.Stable.V1.With_all_version_tags)
             (struct ... end)

           and we add the tag for the current version by
           shadowing the the bin_io functions from that include

           that way, the serialized data gets all version tags

           the type t is the same as in the surrounding module

           we don't add an additional version tag for the original module
           (because we didn't do so for %%versioned_binable, when we
           had all version tags by default)
        *)
        let include_binable_stri = find_include_binable_stri modl_stri in
        let typ_decl =
          (* type `typ` is equal to the type `t` from the surrounding module *)
          let ty_decl =
            type_declaration ~name:(Located.mk "typ") ~params ~cstrs:[]
              ~private_:Public
              ~manifest:
                (Some
                   (ptyp_constr (Located.lident "t") (List.map ~f:fst params))
                )
              ~kind:Ptype_abstract
          in
          let ptype_attributes =
            if t_is_unboxed then [ Lazy.force unboxed_attr ] else []
          in
          { ty_decl with ptype_attributes }
        in
        let include_binable_all_version_tags =
          make_all_tags_binable_include#structure_item include_binable_stri
        in
        make_tag_module ~bin_io_include:include_binable_all_version_tags
          typ_decl with_all_version_tags_module
      else
        let typ_decl =
          (* type `typ` is equal to `t` from the surrounding versioned type; but all contained
             occurrences of the form `M.Stable.Vn.t` become `M.Stable.Vn.With_all_version_tags.t`, so
             those types get version tags when serialized
          *)
          let typ_stri = mk_all_version_tags_type_decl#structure_item t_stri in
          match typ_stri.pstr_desc with
          | Pstr_type (Recursive, [ typ_decl ]) ->
              let ptype_attributes =
                if t_is_unboxed then
                  Lazy.force unboxed_attr :: typ_decl.ptype_attributes
                else typ_decl.ptype_attributes
              in
              { typ_decl with ptype_attributes }
          | _ ->
              Location.raise_errorf ~loc
                "Expected type declaration for type `typ`"
        in
        make_tag_module typ_decl with_all_version_tags_module
    in
    let top_version_tag_modules =
      if not top_version_tag then []
      else
        let open Ast_builder in
        let typ_decl =
          (* type `typ` is equal to the type `t` from the surrounding module *)
          let ty_decl =
            type_declaration ~name:(Located.mk "typ") ~params ~cstrs:[]
              ~private_:Public
              ~manifest:
                (Some
                   (ptyp_constr (Located.lident "t") (List.map ~f:fst params))
                )
              ~kind:Ptype_abstract
          in
          let ptype_attributes =
            if t_is_unboxed then
              [ Lazy.force unboxed_attr; Lazy.force deriving_bin_io ]
            else [ Lazy.force deriving_bin_io ]
          in
          { ty_decl with ptype_attributes }
        in
        make_tag_module typ_decl with_top_version_tag_module
    in
    let version_tag_items =
      yojson_tag_shadows @ all_version_tag_modules @ top_version_tag_modules
    in
    let to_latest_guard_modules =
      (* use of `to_latest`, in case no version tag items *)
      if empty_params && List.is_empty version_tag_items then
        [%str let (_ : _) = to_latest]
      else []
    in
    let register_shape =
      let open Ast_builder in
      match t_stri.pstr_desc with
      | Pstr_type (_, [ ty_decl ]) ->
          (* incomplete shape if there are type parameters *)
          if List.is_empty ty_decl.ptype_params then
            let ty_decl_str = ty_decl_to_string ty_decl in
            [%str
              let (_ : _) =
                let path =
                  Core_kernel.sprintf "%s:%s.%s" __FILE__ __FUNCTION__
                    [%e estring ty_decl.ptype_name.txt]
                in
                Ppx_version_runtime.Shapes.register path bin_shape_t
                  [%e estring ty_decl_str]]
          else []
      | _ ->
          failwith "Expected single type declaration in structure item"
    in
    register_shape @ to_latest_guard_modules @ version_tag_items
  in
  match stri.pstr_desc with
  | Pstr_type _ ->
      (empty_params, [ t ], extra_stris)
  | Pstr_module
      ( { pmb_expr = { pmod_desc = Pmod_structure (stri :: str); _ } as pmod; _ }
      as pmb ) ->
      ( empty_params
      , [ { stri with
            pstr_desc =
              Pstr_module
                { pmb with
                  pmb_expr = { pmod with pmod_desc = Pmod_structure (t :: str) }
                }
          }
        ]
      , extra_stris )
  | _ ->
      assert false

let is_attr_stri = function
  | { pstr_desc = Pstr_attribute _; _ } ->
      true
  | _ ->
      false

let is_attr_stri_with_name name = function
  | { pstr_desc = Pstr_attribute { attr_name = { txt; _ }; _ }; _ }
    when String.equal txt name ->
      true
  | _ ->
      false

let is_attr_sigitem = function
  | { psig_desc = Psig_attribute _; _ } ->
      true
  | _ ->
      false

let is_attr_sigitem_with_name name = function
  | { psig_desc = Psig_attribute { attr_name = { txt; _ }; _ }; _ }
    when String.equal txt name ->
      true
  | _ ->
      false

let convert_module_stri ~version_option ~top_version_tag ~json_version_tag
    last_version modl_stri =
  let module_pattern =
    Ast_pattern.(
      pstr_module (module_binding ~name:(some __') ~expr:(pmod_structure __')))
  in
  let loc = modl_stri.pstr_loc in
  let name, str =
    Ast_pattern.parse module_pattern loc modl_stri
      ~on_error:(fun () ->
        Location.raise_errorf ~loc
          "Expected a statement of the form `module Vn = struct ... end`." )
      (fun name str -> (name, str))
  in
  validate_module_version name.txt name.loc ;
  let version = version_of_versioned_module_name name.txt in
  Option.iter last_version ~f:(fun last_version ->
      if version = last_version then
        (* Mimic wording of the equivalent OCaml error. *)
        Location.raise_errorf ~loc "Multiple definition of the module name V%i."
          version
      else if version >= last_version then
        Location.raise_errorf ~loc
          "Versioned modules must be listed in decreasing order." ) ;
  let attrs, str_no_attrs = List.partition_tf str.txt ~f:is_attr_stri in
  let all_version_tagged =
    List.exists attrs ~f:(is_attr_stri_with_name with_all_version_tags)
  in
  let stri, type_stri, str_rest =
    match str_no_attrs with
    | [] ->
        Location.raise_errorf ~loc:str.loc
          "Expected a type declaration in this structure."
    | ( { pstr_desc =
            Pstr_module
              { pmb_name = { txt = Some "T"; _ }
              ; pmb_expr = { pmod_desc = Pmod_structure (type_stri :: _); _ }
              ; _
              }
        ; _
        } as stri )
      :: ( { pstr_desc =
               Pstr_include
                 { pincl_mod =
                     { pmod_desc = Pmod_ident { txt = Lident "T"; _ }; _ }
                 ; _
                 }
           ; _
           }
           :: _ as str ) ->
        (stri, type_stri, str)
    | type_stri :: str ->
        (type_stri, type_stri, str)
  in
  let should_convert, type_str, extra_stris =
    version_type ~version_option version ~modl_stri ~all_version_tagged
      ~top_version_tag ~json_version_tag stri
  in
  (* TODO: If [should_convert] then look for [to_latest]. *)
  let open Ast_builder.Default in
  ( version
  , pstr_module ~loc
      (module_binding ~loc ~name:(some_loc name)
         ~expr:(pmod_structure ~loc:str.loc (type_str @ str_rest @ extra_stris)) )
  , should_convert
  , type_stri
  , all_version_tagged )

let convert_modbody ~loc ~version_option body =
  let may_convert_latest = ref None in
  let latest_version = ref None in
  let attrs, body_no_attrs = List.partition_tf body ~f:is_attr_stri in
  let no_toplevel_type =
    !no_toplevel_latest_type
    || List.exists attrs ~f:(is_attr_stri_with_name no_toplevel_latest_type_str)
  in
  let json_version_tag =
    List.exists attrs ~f:(is_attr_stri_with_name with_versioned_json)
  in
  let top_version_tag =
    List.exists attrs ~f:(is_attr_stri_with_name with_top_version_tag)
  in
  let _, rev_str, type_stri, top_tag_convs, all_tag_convs, json_tag_convs =
    List.fold ~init:(None, [], None, [], [], []) body_no_attrs
      ~f:(fun
           (version, rev_str, type_stri, top_taggeds, all_taggeds, json_taggeds)
           stri
         ->
        let version, stri, should_convert, current_type_stri, is_all_tagged =
          convert_module_stri ~version_option ~top_version_tag ~json_version_tag
            version stri
        in
        let type_stri =
          Some (Option.value ~default:current_type_stri type_stri)
        in
        ( match !may_convert_latest with
        | None ->
            may_convert_latest := Some should_convert ;
            latest_version := Some version
        | Some _ ->
            () ) ;
        let top_tag_convs =
          if top_version_tag && should_convert then version :: top_taggeds
          else top_taggeds
        in
        let all_tag_convs =
          if is_all_tagged && should_convert then version :: all_taggeds
          else all_taggeds
        in
        let json_tag_convs =
          if json_version_tag && should_convert then version :: json_taggeds
          else json_taggeds
        in
        ( Some version
        , stri :: rev_str
        , type_stri
        , top_tag_convs
        , all_tag_convs
        , json_tag_convs ) )
  in
  let (module Ast_builder) = Ast_builder.make loc in
  let alert_prolog, alert_epilog =
    let open Ast_builder in
    if equal_version_option version_option Binable then
      ( [ [%stri [@@@alert "-legacy-deprecated"]] ]
      , [ [%stri [@@@alert "+legacy+deprecated"]] ] )
    else ([], [])
  in
  let rev_str =
    match !latest_version with
    | Some latest_version -> (
        let open Ast_builder in
        let latest =
          pstr_module
            (module_binding
               ~name:(some_loc (Located.mk "Latest"))
               ~expr:
                 (pmod_ident (Located.lident (sprintf "V%i" latest_version))) )
        in
        (* insert Latest alias after latest versioned module
           so subsequent modules can mention it
        *)
        match List.rev rev_str with
        | vn :: vs ->
            List.rev (vn :: latest :: vs)
        | [] ->
            (* should be unreachable *)
            [ latest ] )
    | None ->
        rev_str
  in
  let rev_str_with_converters =
    match !may_convert_latest with
    | Some true ->
        let converter_modules =
          let top_tag_modules =
            if not top_version_tag then []
            else
              let top_tag_versions =
                [%stri
                  (* NOTE: This will give a type error if any of the [to_latest]
                     values do not convert to [Latest.t].
                  *)
                  let (top_tag_versions :
                        ( int
                        * (   Core_kernel.Bigstring.t
                           -> pos_ref:int ref
                           -> Latest.t ) )
                        array ) =
                    [%e
                      let open Ast_builder in
                      pexp_array
                        (List.map top_tag_convs ~f:(fun version ->
                             let version_module =
                               Longident.Lident (sprintf "V%i" version)
                             in
                             let dot x =
                               let open Longident in
                               Located.mk (Ldot (version_module, x))
                             in
                             let dot_with_module module_ x =
                               let open Longident in
                               Located.mk
                                 (Ldot (Ldot (version_module, module_), x))
                             in
                             pexp_tuple
                               [ eint version
                               ; [%expr
                                   fun buf ~pos_ref ->
                                     [%e
                                       pexp_ident
                                         (dot_with_module
                                            with_top_version_tag_module
                                            "bin_read_t" )]
                                       buf ~pos_ref
                                     |> [%e pexp_ident (dot "to_latest")]]
                               ] ) )]]
              in
              let top_tag_convert =
                [%stri
                  (** deserializes data to the latest module version's type *)
                  let bin_read_top_tagged_to_latest buf ~pos_ref =
                    let open Core_kernel in
                    (* Rely on layout, assume that the first element of the record is
                       at pos_ref in the buffer
                       The reader `f` will re-read the version, so we save the
                       position and restore pos_ref
                    *)
                    let saved_pos = !pos_ref in
                    let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
                    let pos_ref = ref saved_pos in
                    match
                      Array.find_map top_tag_versions ~f:(fun (i, f) ->
                          if Int.equal i version then Some (f buf ~pos_ref)
                          else None )
                    with
                    | Some v ->
                        Ok v
                    | None ->
                        Error
                          (Error.of_string
                             (sprintf "Could not find top-tagged version %d"
                                version ) )]
              in
              let top_tag_convert_guard =
                [%stri let (_ : _) = bin_read_top_tagged_to_latest]
              in
              [ top_tag_convert_guard; top_tag_convert; top_tag_versions ]
          in
          let all_tag_modules =
            if List.is_empty all_tag_convs then []
            else
              let all_tag_versions =
                [%stri
                  (* NOTE: This will give a type error if any of the [to_latest]
                     values do not convert to [Latest.t].
                  *)
                  let (all_tag_versions :
                        ( int
                        * (   Core_kernel.Bigstring.t
                           -> pos_ref:int ref
                           -> Latest.t ) )
                        array ) =
                    [%e
                      let open Ast_builder in
                      pexp_array
                        (List.map all_tag_convs ~f:(fun version ->
                             let version_module =
                               Longident.Lident (sprintf "V%i" version)
                             in
                             let dot x =
                               let open Longident in
                               Located.mk (Ldot (version_module, x))
                             in
                             let dot_with_module module_ x =
                               let open Longident in
                               Located.mk
                                 (Ldot (Ldot (version_module, module_), x))
                             in
                             pexp_tuple
                               [ eint version
                               ; [%expr
                                   fun buf ~pos_ref ->
                                     [%e
                                       pexp_ident
                                         (dot_with_module
                                            with_all_version_tags_module
                                            "bin_read_t" )]
                                       buf ~pos_ref
                                     |> [%e pexp_ident (dot "to_latest")]]
                               ] ) )]]
              in
              let all_tag_convert =
                [%stri
                  (** deserializes data to the latest module version's type *)
                  let bin_read_all_tagged_to_latest buf ~pos_ref =
                    let open Core_kernel in
                    (* Rely on layout, assume that the first element of the record is
                       at pos_ref in the buffer
                       The reader `f` will re-read the version, so we save the
                       position and restore pos_ref
                    *)
                    let saved_pos = !pos_ref in
                    let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
                    let pos_ref = ref saved_pos in
                    match
                      Array.find_map all_tag_versions ~f:(fun (i, f) ->
                          if Int.equal i version then Some (f buf ~pos_ref)
                          else None )
                    with
                    | Some v ->
                        Ok v
                    | None ->
                        Error
                          (Error.of_string
                             (sprintf "Could not find all-tagged version %d"
                                version ) )]
              in
              let all_tag_convert_guard =
                [%stri let (_ : _) = bin_read_all_tagged_to_latest]
              in
              [ all_tag_convert_guard; all_tag_convert; all_tag_versions ]
          in
          let json_tag_modules =
            if not json_version_tag then []
            else
              let json_tag_versions =
                [%stri
                  let (json_tag_versions :
                        ( int
                        * (Yojson.Safe.t -> Latest.t Core_kernel.Or_error.t) )
                        array ) =
                    [%e
                      let open Ast_builder in
                      pexp_array
                        (List.map json_tag_convs ~f:(fun version ->
                             let version_module =
                               Longident.Lident (sprintf "V%i" version)
                             in
                             let dot x =
                               let open Longident in
                               Located.mk (Ldot (version_module, x))
                             in
                             pexp_tuple
                               [ eint version
                               ; [%expr
                                   fun json ->
                                     match
                                       [%e
                                         pexp_apply
                                           (pexp_ident (dot "of_yojson"))
                                           [ ( Nolabel
                                             , pexp_ident
                                                 (Located.mk (Lident "json")) )
                                           ]]
                                     with
                                     | Ppx_deriving_yojson_runtime.Result.Ok v
                                       ->
                                         Ok
                                           [%e
                                             pexp_apply
                                               (pexp_ident (dot "to_latest"))
                                               [ ( Nolabel
                                                 , pexp_ident
                                                     (Located.mk (Lident "v"))
                                                 )
                                               ]]
                                     | Ppx_deriving_yojson_runtime.Result.Error
                                         err ->
                                         Error (Error.of_string err)]
                               ] ) )]]
              in
              let json_tag_convert =
                [%stri
                  (** deserializes JSON to the latest module version's type *)
                  let of_yojson_to_latest (json : Yojson.Safe.t) :
                      Latest.t Core_kernel.Or_error.t =
                    match json with
                    | `Assoc [ ("version", `Int version); ("data", _) ] -> (
                        match
                          Array.find_map json_tag_versions ~f:(fun (i, f) ->
                              if Int.equal i version then Some (f json)
                              else None )
                        with
                        | Some v ->
                            v
                        | None ->
                            Error
                              (Error.of_string
                                 (sprintf
                                    "Could not find json-tagged version %d"
                                    version ) ) )
                    | _ ->
                        Error (Error.of_string "Expected versioned JSON")]
              in
              let json_tag_convert_guard =
                [%stri let (_ : _) = of_yojson_to_latest]
              in
              [ json_tag_convert_guard; json_tag_convert; json_tag_versions ]
          in
          json_tag_modules @ top_tag_modules @ all_tag_modules
        in
        converter_modules @ rev_str
    | _ ->
        rev_str
  in
  let rev_str_with_all =
    alert_epilog @ rev_str_with_converters @ alert_prolog
  in
  (List.rev rev_str_with_all, if no_toplevel_type then None else type_stri)

let version_module ~loc ~path:_ ~version_option modname modbody =
  Printexc.record_backtrace true ;
  try
    let modname = map_loc ~f:(check_modname ~loc:modname.loc) modname in
    let modbody_txt, type_stri =
      convert_modbody ~version_option ~loc:modbody.loc modbody.txt
    in
    let modbody = { Location.txt = modbody_txt; loc = modbody.loc } in
    let open Ast_helper in
    let type_stri =
      Option.map ~f:erase_stable_versions#structure_item type_stri
      |> Option.to_list
    in
    let empty_binding =
      [%str
        let (_ : _) =
          (module Stable.Latest : Ppx_version_runtime.Util.Empty_signature)]
    in
    Str.include_ ~loc
      (Incl.mk ~loc
         (Ast_helper.Mod.structure ~loc
            ( Str.module_ ~loc
                (Mb.mk ~loc:modname.loc (some_loc modname)
                   (Mod.structure ~loc:modbody.loc modbody.txt) )
              :: type_stri
            @ empty_binding ) ) )
  with exn ->
    Format.(fprintf err_formatter "%s@." (Printexc.get_backtrace ())) ;
    raise exn

let convert_rpc_version (stri : structure_item) =
  let register_shapes query_ty_decl response_ty_decl =
    let (module Ast_builder) = Ast_builder.make stri.pstr_loc in
    let open Ast_builder in
    let query_ty_decl_str = ty_decl_to_string query_ty_decl in
    let response_ty_decl_str = ty_decl_to_string response_ty_decl in
    [%str
      let (_ : _) =
        let query_path =
          Core_kernel.sprintf "%s:%s.%s" __FILE__ __FUNCTION__
            [%e estring "query"]
        in
        Ppx_version_runtime.Shapes.register query_path bin_shape_query
          [%e estring query_ty_decl_str] ;
        let response_path =
          Core_kernel.sprintf "%s:%s.%s" __FILE__ __FUNCTION__
            [%e estring "response"]
        in
        Ppx_version_runtime.Shapes.register response_path bin_shape_response
          [%e estring response_ty_decl_str]]
  in
  let add_derivers_to_types = function
    | { pstr_desc = Pstr_type (rec_flag, [ ty_decl ]); pstr_loc }
      when List.mem [ "query"; "response" ] ty_decl.ptype_name.txt
             ~equal:String.equal ->
        let ty_decl_with_attrs =
          { ty_decl with
            ptype_attributes =
              add_deriving ~loc:ty_decl.ptype_loc ~version_option:Rpc
                ty_decl.ptype_attributes
          }
        in
        { pstr_desc = Pstr_type (rec_flag, [ ty_decl_with_attrs ]); pstr_loc }
    | item ->
        item
  in
  match stri.pstr_desc with
  | Pstr_module ({ pmb_name; pmb_expr; _ } as mod_binding)
    when Option.is_some pmb_name.txt
         && Versioned_util.is_version_module (Option.value_exn pmb_name.txt)
    -> (
      match pmb_expr with
      | { pmod_desc =
            Pmod_structure
              (( { pstr_desc =
                     Pstr_module
                       ( { pmb_name = { txt = Some "T"; _ }
                         ; pmb_expr =
                             { pmod_desc = Pmod_structure str_items; _ } as
                             inner_mod_expr
                         ; _
                         } as inner_mod_binding )
                 ; _
                 } as inner_str_item )
              :: other_mods )
        ; _
        } as mod_expr ->
          (* query, response types in module T contained in Vn module *)
          let str_items_with_derivers =
            List.map str_items ~f:add_derivers_to_types
          in
          let ty_decls =
            List.filter_map str_items_with_derivers ~f:(fun stri ->
                match stri.pstr_desc with
                | Pstr_type (Recursive, [ ty_decl ]) ->
                    Some ty_decl
                | _ ->
                    None )
          in
          let query_ty_decl =
            List.find_exn ty_decls ~f:(fun ty_decl ->
                String.equal ty_decl.ptype_name.txt "query" )
          in
          let response_ty_decl =
            List.find_exn ty_decls ~f:(fun ty_decl ->
                String.equal ty_decl.ptype_name.txt "response" )
          in
          let pmb_expr_with_derivers =
            { mod_expr with
              pmod_desc =
                Pmod_structure
                  ( { inner_str_item with
                      pstr_desc =
                        Pstr_module
                          { inner_mod_binding with
                            pmb_expr =
                              { inner_mod_expr with
                                pmod_desc =
                                  Pmod_structure
                                    ( str_items_with_derivers
                                    @ register_shapes query_ty_decl
                                        response_ty_decl )
                              }
                          }
                    }
                  :: other_mods )
            }
          in
          { stri with
            pstr_desc =
              Pstr_module { mod_binding with pmb_expr = pmb_expr_with_derivers }
          }
      | _ ->
          failwith "Expected structure in RPC version module" )
  | _ ->
      stri

let check_rpc_versioned_module_numbers stris =
  ignore
    ( List.fold stris ~init:None ~f:(fun last_vn stri ->
          match stri.pstr_desc with
          | Pstr_module { pmb_name; _ }
            when Option.is_some pmb_name.txt
                 && Versioned_util.is_version_module
                      (Option.value_exn pmb_name.txt) -> (
              let current_vn =
                Versioned_util.version_of_versioned_module_name
                  (Option.value_exn pmb_name.txt)
              in
              match last_vn with
              | None ->
                  Some current_vn
              | Some vn ->
                  if current_vn = vn then
                    Location.raise_errorf ~loc:stri.pstr_loc
                      "Duplicate versions in versioned RPC modules" ;
                  if current_vn > vn then
                    Location.raise_errorf ~loc:stri.pstr_loc
                      "Versioned RPC modules must be listed in decreasing order" ;
                  Some current_vn )
          | _ ->
              last_vn )
      : int option )

let version_rpc_module ~loc ~path:_ rpc_name (rpc_body : structure_item list loc)
    =
  Printexc.record_backtrace true ;
  try
    check_rpc_versioned_module_numbers rpc_body.txt ;
    let rpc_body_txt = List.map rpc_body.txt ~f:convert_rpc_version in
    let open Ast_helper in
    Str.include_ ~loc
      (Incl.mk ~loc
         (Ast_helper.Mod.structure ~loc
            [ Str.module_ ~loc
                (Mb.mk ~loc:rpc_body.loc (some_loc rpc_name)
                   (Mod.structure ~loc:rpc_body.loc rpc_body_txt) )
            ] ) )
  with exn ->
    Format.(fprintf err_formatter "%s@." (Printexc.get_backtrace ())) ;
    raise exn

(* code for module declarations in signatures

   - add deriving bin_io, version to list of deriving items for the type "t" in versioned modules
   - add "module Latest = Vn" to Stable module
   - if Stable.Latest.t has no parameters:
     - if "with_versioned_json" annotation present, add "of_yojson_to_latest"
     - if "with_top_version_tag" annotation present, add "bin_read_top_tagged_to_latest"
     - if any "with_all_version_tags" annotation is present, add "bin_read_all_tagged_to_latest"
*)

(* parameterless_t means the type t in the module type has no parameters *)
type sig_accum =
  { sigitems : signature
  ; parameterless_t : bool
  ; type_decl : signature_item option
  }

let convert_module_type_signature_item { sigitems; parameterless_t; type_decl }
    sigitem : sig_accum =
  match sigitem.psig_desc with
  | Psig_type
      ( recflag
      , [ ( { ptype_name = { txt = "t"; loc }
            ; ptype_attributes
            ; ptype_params
            ; _
            } as type_ )
        ] ) ->
      let ptype_attributes' =
        add_deriving ~loc ~version_option:No_version_option ptype_attributes
      in
      let psig_desc =
        Psig_type
          (recflag, [ { type_ with ptype_attributes = ptype_attributes' } ])
      in
      let parameterless_t = List.is_empty ptype_params in
      let type_decl = Some (erase_stable_versions#signature_item sigitem) in
      { sigitems = { sigitem with psig_desc } :: sigitems
      ; parameterless_t
      ; type_decl
      }
  | _ ->
      { sigitems = sigitem :: sigitems; parameterless_t; type_decl }

let convert_module_type_signature signature : sig_accum =
  List.fold signature
    ~init:{ sigitems = []; parameterless_t = false; type_decl = None }
    ~f:convert_module_type_signature_item

type module_type_with_convertible =
  { module_type : module_type
  ; convertible : bool
  ; extra_items : signature_item list
  }

(* add deriving items to type t in module type *)
let convert_module_type ~loc ~top_version_tagged mod_ty =
  match mod_ty.pmty_desc with
  | Pmty_signature signature ->
      let attrs = List.filter signature ~f:is_attr_sigitem in
      let make_tag_module_decl mod_name =
        let (module Ast_builder) = Ast_builder.make loc in
        let open Ast_builder in
        (* mod_name : Bin_prot.Binable.S with type t = t *)
        psig_module
          (module_declaration
             ~name:(Located.mk @@ Some mod_name)
             ~type_:
               (pmty_with
                  (pmty_ident
                     ( Located.mk
                     @@ Ldot (Ldot (Lident "Bin_prot", "Binable"), "S") ) )
                  [ Pwith_type
                      ( Located.mk (Lident "t")
                      , Ast_builder.type_declaration ~name:(Located.mk "t")
                          ~params:[] ~cstrs:[] ~kind:Ptype_abstract
                          ~private_:Public
                          ~manifest:(Some (ptyp_constr (Located.lident "t") []))
                      )
                  ] ) )
      in
      let with_top_version_tag_decl =
        if top_version_tagged then
          [ make_tag_module_decl with_top_version_tag_module ]
        else []
      in
      let all_version_tagged =
        List.exists attrs ~f:(is_attr_sigitem_with_name with_all_version_tags)
      in
      let with_all_version_tags_decl =
        if all_version_tagged then
          [ make_tag_module_decl with_all_version_tags_module ]
        else []
      in
      let with_version_tags_decls =
        with_top_version_tag_decl @ with_all_version_tags_decl
      in
      let { sigitems; parameterless_t; type_decl } =
        convert_module_type_signature signature
      in
      let sigitems' = List.rev sigitems @ with_version_tags_decls in
      { module_type = { mod_ty with pmty_desc = Pmty_signature sigitems' }
      ; convertible = parameterless_t
      ; extra_items = Option.to_list type_decl
      }
  | _ ->
      Location.raise_errorf ~loc:mod_ty.pmty_loc
        "Expected versioned module type to be a signature"

(* latest is the name of the module to be equated with Latest
   last is the last module seen in the fold
   convertible is true if the latest module's type t has no parameters
   sigitems are the signature for the module, in reverse order
*)
type module_accum =
  { latest : string option
  ; last : int option
  ; convertible : bool
  ; sigitems : signature
  ; extra_sigitems : signature
  }

(* convert modules Vn ... V1 contained in Stable *)
let convert_module_decls signature =
  let init =
    { latest = None
    ; last = None
    ; convertible = false
    ; sigitems = []
    ; extra_sigitems = []
    }
  in
  let convert ~no_toplevel_latest ~top_version_tagged
      { latest; last; convertible; sigitems; extra_sigitems } sigitem =
    match sigitem.psig_desc with
    | Psig_module ({ pmd_name = { txt = Some name; loc }; pmd_type; _ } as pmd)
      ->
        validate_module_version name loc ;
        let version = version_of_versioned_module_name name in
        Option.iter last ~f:(fun n ->
            if Int.equal version n then
              Location.raise_errorf ~loc
                "Duplicate versions in versioned modules" ;
            if Int.( > ) version n then
              Location.raise_errorf ~loc
                "Versioned modules must be listed in decreasing order" ) ;
        let in_latest = Option.is_none latest in
        let latest = if in_latest then Some name else latest in
        let { module_type; convertible = module_convertible; extra_items } =
          convert_module_type ~loc ~top_version_tagged pmd_type
        in
        let psig_desc' = Psig_module { pmd with pmd_type = module_type } in
        let sigitem' = { sigitem with psig_desc = psig_desc' } in
        (* use current convertible if in latest module, else the accumulated convertible *)
        let convertible =
          if in_latest then module_convertible else convertible
        in
        let extra_sigitems =
          if in_latest && not no_toplevel_latest then extra_items
          else extra_sigitems
        in
        { latest
        ; last = Some version
        ; convertible
        ; sigitems = sigitem' :: sigitems
        ; extra_sigitems
        }
    | _ ->
        Location.raise_errorf ~loc:sigitem.psig_loc
          "Expected versioned module declaration"
  in
  let sig_attrs, signature_no_attrs =
    List.partition_tf signature ~f:is_attr_sigitem
  in
  let no_toplevel_latest =
    !no_toplevel_latest_type
    || List.exists sig_attrs
         ~f:(is_attr_sigitem_with_name no_toplevel_latest_type_str)
  in
  let top_version_tagged =
    List.exists sig_attrs ~f:(is_attr_sigitem_with_name with_top_version_tag)
  in
  ( sig_attrs
  , List.fold signature_no_attrs ~init
      ~f:(convert ~no_toplevel_latest ~top_version_tagged) )

let version_module_decl ~loc ~path:_ modname signature =
  Printexc.record_backtrace true ;
  try
    let open Ast_helper in
    let modname = map_loc ~f:(check_modname ~loc:modname.loc) modname in
    let sig_attrs, { latest; sigitems; convertible; extra_sigitems; _ } =
      convert_module_decls signature.txt
    in
    let json_version_tag =
      List.exists sig_attrs ~f:(is_attr_sigitem_with_name with_versioned_json)
    in
    let top_version_tag =
      List.exists sig_attrs ~f:(is_attr_sigitem_with_name with_top_version_tag)
    in
    let all_version_tagged =
      List.exists sigitems ~f:(fun sigitem ->
          match sigitem.psig_desc with
          | Psig_module
              { pmd_type = { pmty_desc = Pmty_signature items; _ }; _ } ->
              List.exists items
                ~f:(is_attr_sigitem_with_name with_all_version_tags)
          | _ ->
              false )
    in
    let mk_module_decl name ty_desc =
      Sig.mk ~loc
        (Psig_module (Md.mk ~loc (some_loc name) (Mty.mk ~loc ty_desc)))
    in
    let signature =
      match latest with
      | None ->
          List.rev sigitems
      | Some vn ->
          let module E = Ppxlib.Ast_builder.Make (struct
            let loc = loc
          end) in
          let open E in
          let latest =
            mk_module_decl { txt = "Latest"; loc }
              (Pmty_alias { txt = Lident vn; loc })
          in
          let defs =
            if convertible then
              let json_version_modules =
                if json_version_tag then
                  [ [%sigi:
                      val of_yojson_to_latest :
                        Yojson.Safe.t -> Latest.t Core_kernel.Or_error.t]
                  ]
                else []
              in
              let top_version_modules =
                if top_version_tag then
                  [ [%sigi:
                      val bin_read_top_tagged_to_latest :
                           Bin_prot.Common.buf
                        -> pos_ref:int ref
                        -> Latest.t Core_kernel.Or_error.t]
                  ]
                else []
              in
              let all_version_modules =
                if all_version_tagged then
                  [ [%sigi:
                      val bin_read_all_tagged_to_latest :
                           Bin_prot.Common.buf
                        -> pos_ref:int ref
                        -> Latest.t Core_kernel.Or_error.t]
                  ]
                else []
              in
              json_version_modules @ top_version_modules @ all_version_modules
            else []
          in
          (* insert Latest alias after latest version module decl
             so subsequent module decls can mention it
          *)
          let sigitems_with_latest =
            match List.rev sigitems with
            | vn :: vs ->
                vn :: latest :: vs
            | [] ->
                (* should be unreachable *)
                [ latest ]
          in
          sigitems_with_latest @ defs
    in
    let sigi = mk_module_decl modname (Pmty_signature signature) in
    match extra_sigitems with
    | [] ->
        sigi
    | _ ->
        let open Ast_helper in
        Sig.mk ~loc
          (Psig_include
             (Incl.mk ~loc (Mty.signature ~loc (sigi :: extra_sigitems))) )
  with exn ->
    Format.(fprintf err_formatter "%s@." (Printexc.get_backtrace ())) ;
    raise exn

let () =
  let module_ast_pattern =
    Ast_pattern.(
      pstr
        ( pstr_module
            (module_binding ~name:(some __') ~expr:(pmod_structure __'))
        ^:: nil ))
  in
  let module_extension =
    Extension.(
      declare "versioned" Context.structure_item module_ast_pattern
        (version_module ~version_option:No_version_option))
  in
  let module_extension_binable =
    Extension.(
      declare "versioned_binable" Context.structure_item module_ast_pattern
        (version_module ~version_option:Binable))
  in
  let module_extension_rpc =
    Extension.(
      declare "versioned_rpc" Context.structure_item module_ast_pattern
        version_rpc_module)
  in
  let module_decl_ast_pattern =
    Ast_pattern.(
      psig
        ( psig_module
            (module_declaration ~name:(some __') ~type_:(pmty_signature __'))
        ^:: nil ))
  in
  let module_decl_extension =
    Extension.(
      declare "versioned" Context.signature_item module_decl_ast_pattern
        version_module_decl)
  in
  let module_rule = Context_free.Rule.extension module_extension in
  let module_rule_binable =
    Context_free.Rule.extension module_extension_binable
  in
  let module_rule_rpc = Context_free.Rule.extension module_extension_rpc in
  let module_decl_rule = Context_free.Rule.extension module_decl_extension in
  let rules =
    [ module_rule; module_rule_binable; module_rule_rpc; module_decl_rule ]
  in
  Driver.register_transformation "ppx_version/versioned_module" ~rules ;
  Ppxlib.Driver.add_arg "--no-toplevel-latest-type"
    (Caml.Arg.Unit (fun () -> no_toplevel_latest_type := true))
    ~doc:"Disable the toplevel type t declaration for versioned type modules" ;
  Ppxlib.Driver.add_arg "--toplevel-latest-type"
    (Caml.Arg.Bool (fun b -> no_toplevel_latest_type := not b))
    ~doc:
      "Enable or disable the toplevel type t declaration for versioned type \
       modules"
