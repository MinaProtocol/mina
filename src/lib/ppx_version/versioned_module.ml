open Core_kernel
open Ppxlib
open Versioned_util

let no_toplevel_latest_type = ref false

(* option to `deriving version' *)
type version_option = No_version_option | Asserted | Binable

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
    | Asserted ->
        [%expr version { asserted }]
    | Binable ->
        [%expr version { binable }]
  in
  match attributes with
  | [] ->
      let attr_name = mk_loc ~loc "deriving" in
      let attr_payload =
        match version_option with
        | No_version_option | Asserted ->
            payload [ [%expr bin_io]; version_expr ]
        | Binable ->
            payload [ version_expr ]
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
            | No_version_option | Asserted ->
                true
            | Binable ->
                false
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

    method! core_type typ =
      match typ.ptyp_desc with
      | Ptyp_constr
          ({ txt = Ldot (Ldot (Ldot (lid, "Stable"), vn), "t"); loc }, typs)
        when try
               validate_module_version vn loc ;
               true
             with _ -> false ->
          (* Erase [.Stable.Vn.t] to [.t] *)
          let typ =
            { typ with
              ptyp_desc = Ptyp_constr ({ txt = Ldot (lid, "t"); loc }, typs)
            }
          in
          super#core_type typ
      | _ ->
          super#core_type typ

    method! type_declaration typ =
      let typ = super#type_declaration typ in
      let ptype_attributes : attributes =
        List.filter_map typ.ptype_attributes
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
      { typ with
        ptype_attributes
      ; ptype_manifest =
          Some
            (Ast_helper.Typ.constr ~loc:typ.ptype_loc
               { Location.txt = Longident.parse "Stable.Latest.t"
               ; loc = typ.ptype_loc
               }
               (List.map ~f:fst typ.ptype_params) )
      }
  end

let version_type ~version_option version stri =
  let loc = stri.pstr_loc in
  let t, params =
    let subst_type stri =
      (* NOTE: Can't use [Ast_pattern] here; it rejects attributes attached to
         types..
      *)
      match stri.pstr_desc with
      | Pstr_type
          ( rec_flag
          , [ ( { ptype_name = { txt = "t"; _ }; ptype_private = Public; _ } as
              typ )
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
          (t, params)
      | _ ->
          (* TODO: Handle rpc types. *)
          Location.raise_errorf ~loc:stri.pstr_loc
            "Expected a single public type t."
    in
    match stri.pstr_desc with
    | Pstr_type _ ->
        subst_type stri
    | Pstr_module
        { pmb_expr = { pmod_desc = Pmod_structure (stri :: _); _ }; _ } ->
        subst_type stri
    | _ ->
        (* TODO: Handle rpc types. *)
        Location.raise_errorf ~loc:stri.pstr_loc
          "Expected a single public type t, or a module T."
  in
  let (module Ast_builder) = Ast_builder.make loc in
  let with_version =
    let open Ast_builder in
    let typ =
      type_declaration ~name:(Located.mk "typ") ~params ~cstrs:[]
        ~private_:Public
        ~manifest:
          (Some (ptyp_constr (Located.lident "t") (List.map ~f:fst params)))
        ~kind:Ptype_abstract
    in
    let t_deriving =
      create_attr ~loc (Located.mk "deriving") (PStr [ [%stri bin_io] ])
    in
    let typ =
      { typ with ptype_attributes = t_deriving :: typ.ptype_attributes }
    in
    let t =
      type_declaration ~name:(Located.mk "t") ~params ~cstrs:[] ~private_:Public
        ~manifest:None
        ~kind:
          (Ptype_record
             [ label_declaration ~name:(Located.mk "version")
                 ~mutable_:Immutable
                 ~type_:(ptyp_constr (Located.lident "int") [])
             ; label_declaration ~name:(Located.mk "t") ~mutable_:Immutable
                 ~type_:
                   (ptyp_constr (Located.lident "typ") (List.map ~f:fst params))
             ] )
    in
    let t = { t with ptype_attributes = t_deriving :: t.ptype_attributes } in
    let create = [%stri let create t = { t; version = [%e eint version] }] in
    pstr_module
      (module_binding
         ~name:(some_loc (Located.mk "With_version"))
         ~expr:
           (pmod_structure
              [ pstr_type Recursive [ typ ]; pstr_type Recursive [ t ]; create ] ) )
  in
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
  let bin_io_shadows =
    [ [%stri
        let bin_read_t =
          [%e
            fun_args
              [%expr
                fun buf ~pos_ref ->
                  let With_version.{ version = read_version; t } =
                    [%e apply_args [%expr With_version.bin_read_t]] buf ~pos_ref
                  in
                  (* sanity check *)
                  if not (Core_kernel.Int.equal read_version version) then
                    failwith
                      (Core_kernel.sprintf
                         "bin_read_t: version read %d does not match expected \
                          version %d"
                         read_version version ) ;
                  t]]]
    ; [%stri
        let __bin_read_t__ =
          [%e
            fun_args
              [%expr
                fun buf ~pos_ref i ->
                  let With_version.{ version = read_version; t } =
                    [%e apply_args [%expr With_version.__bin_read_t__]]
                      buf ~pos_ref i
                  in
                  (* sanity check *)
                  if not (Core_kernel.Int.equal read_version version) then
                    failwith
                      (Core_kernel.sprintf
                         "__bin_read_t__: version read %d does not match \
                          expected version %d"
                         read_version version ) ;
                  t]]]
    ; [%stri
        let bin_size_t =
          [%e
            fun_args
              [%expr
                fun t ->
                  With_version.create t
                  |> [%e apply_args [%expr With_version.bin_size_t]]]]]
    ; [%stri
        let bin_write_t =
          [%e
            fun_args
              [%expr
                fun buf ~pos t ->
                  With_version.create t
                  |> [%e apply_args [%expr With_version.bin_write_t]] buf ~pos]]]
    ; [%stri let bin_shape_t = With_version.bin_shape_t]
    ; [%stri
        let bin_reader_t =
          [%e
            fun_args
              [%expr
                { Bin_prot.Type_class.read =
                    [%e apply_args ~f:(mk_field "read") [%expr bin_read_t]]
                ; vtag_read =
                    [%e apply_args ~f:(mk_field "read") [%expr __bin_read_t__]]
                }]]]
    ; [%stri
        let bin_writer_t =
          [%e
            fun_args
              [%expr
                { Bin_prot.Type_class.size =
                    [%e apply_args ~f:(mk_field "size") [%expr bin_size_t]]
                ; write =
                    [%e apply_args ~f:(mk_field "write") [%expr bin_write_t]]
                }]]]
    ; [%stri
        let bin_t =
          [%e
            fun_args
              [%expr
                { Bin_prot.Type_class.shape =
                    [%e apply_args ~f:(mk_field "shape") [%expr bin_shape_t]]
                ; writer =
                    [%e apply_args ~f:(mk_field "writer") [%expr bin_writer_t]]
                ; reader =
                    [%e apply_args ~f:(mk_field "reader") [%expr bin_reader_t]]
                }]]]
    ; [%stri
        (* ppx_js_style rejects a single underscore *)
        let __ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )]
    ]
  in
  match stri.pstr_desc with
  | Pstr_type _ ->
      (List.is_empty params, [ t ], with_version :: bin_io_shadows)
  | Pstr_module
      ( { pmb_expr = { pmod_desc = Pmod_structure (stri :: str); _ } as pmod; _ }
      as pmb ) ->
      ( List.is_empty params
      , [ { stri with
            pstr_desc =
              Pstr_module
                { pmb with
                  pmb_expr = { pmod with pmod_desc = Pmod_structure (t :: str) }
                }
          }
        ]
      , with_version :: bin_io_shadows )
  | _ ->
      assert false

let convert_module_stri ~version_option last_version stri =
  let module_pattern =
    Ast_pattern.(
      pstr_module (module_binding ~name:(some __') ~expr:(pmod_structure __')))
  in
  let loc = stri.pstr_loc in
  let name, str =
    Ast_pattern.parse module_pattern loc stri
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
  let stri, type_stri, str_rest =
    match str.txt with
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
  let should_convert, type_str, with_version_bin_io_shadows =
    version_type ~version_option version stri
  in
  (* TODO: If [should_convert] then look for [to_latest]. *)
  let open Ast_builder.Default in
  ( version
  , pstr_module ~loc
      (module_binding ~loc ~name:(some_loc name)
         ~expr:
           (pmod_structure ~loc:str.loc
              (type_str @ str_rest @ with_version_bin_io_shadows) ) )
  , should_convert
  , type_stri )

let convert_modbody ~loc ~version_option body =
  let may_convert_latest = ref None in
  let latest_version = ref None in
  let _, rev_str, convs, type_stri, _no_toplevel_type =
    List.fold ~init:(None, [], [], None, !no_toplevel_latest_type) body
      ~f:(fun (version, rev_str, convs, type_stri, no_toplevel_type) stri ->
        match stri.pstr_desc with
        | Pstr_attribute { attr_name; _ }
          when String.equal attr_name.txt "no_toplevel_latest_type" ->
            (version, rev_str, convs, None, true)
        | _ ->
            let version, stri, should_convert, current_type_stri =
              convert_module_stri ~version_option version stri
            in
            let type_stri =
              if no_toplevel_type then None
              else Some (Option.value ~default:current_type_stri type_stri)
            in
            ( match !may_convert_latest with
            | None ->
                may_convert_latest := Some should_convert ;
                latest_version := Some version
            | Some _ ->
                () ) ;
            let convs = if should_convert then version :: convs else convs in
            (Some version, stri :: rev_str, convs, type_stri, no_toplevel_type) )
  in
  let (module Ast_builder) = Ast_builder.make loc in
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
  let rev_str =
    match !may_convert_latest with
    | Some true ->
        let versions =
          [%stri
            (* NOTE: This will give a type error if any of the [to_latest]
               values do not convert to [Latest.t].
            *)
            let (versions :
                  ( int
                  * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t) )
                  array ) =
              [%e
                let open Ast_builder in
                pexp_array
                  (List.map convs ~f:(fun version ->
                       let version_module =
                         Longident.Lident (sprintf "V%i" version)
                       in
                       let dot x =
                         Located.mk (Longident.Ldot (version_module, x))
                       in
                       pexp_tuple
                         [ eint version
                         ; [%expr
                             fun buf ~pos_ref ->
                               [%e pexp_ident (dot "bin_read_t")] buf ~pos_ref
                               |> [%e pexp_ident (dot "to_latest")]]
                         ] ) )]]
        in
        let convert =
          [%stri
            (** deserializes data to the latest module version's type *)
            let bin_read_to_latest_opt buf ~pos_ref =
              let open Core_kernel in
              (* Rely on layout, assume that the first element of the record is
                 at pos_ref in the buffer
                 The reader `f` will re-read the version, so we save the
                 position and restore pos_ref
              *)
              let saved_pos = !pos_ref in
              let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
              let pos_ref = ref saved_pos in
              Array.find_map versions ~f:(fun (i, f) ->
                  if Int.equal i version then Some (f buf ~pos_ref) else None )]
        in
        let convert_guard = [%stri let __ = bin_read_to_latest_opt] in
        convert_guard :: convert :: versions :: rev_str
    | _ ->
        rev_str
  in
  (List.rev rev_str, type_stri)

let version_module ~loc ~version_option ~path:_ modname modbody =
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
    Str.include_ ~loc
      (Incl.mk ~loc
         (Ast_helper.Mod.structure ~loc
            ( Str.module_ ~loc
                (Mb.mk ~loc:modname.loc (some_loc modname)
                   (Mod.structure ~loc:modbody.loc modbody.txt) )
            :: type_stri ) ) )
  with exn ->
    Format.(fprintf err_formatter "%s@." (Printexc.get_backtrace ())) ;
    raise exn

(* code for module declarations in signatures

   - add deriving bin_io, version to list of deriving items for the type "t" in versioned modules
   - add "module Latest = Vn" to Stable module
   - if Stable.Latest.t has no parameters, add signature items for "versions" and "bin_read_to_latest_opt"
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
let convert_module_type mod_ty =
  match mod_ty.pmty_desc with
  | Pmty_signature signature ->
      let { sigitems; parameterless_t; type_decl } =
        convert_module_type_signature signature
      in
      { module_type =
          { mod_ty with pmty_desc = Pmty_signature (List.rev sigitems) }
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
  ; no_toplevel_latest : bool
  }

(* convert modules Vn ... V1 contained in Stable *)
let convert_module_decls ~loc:_ signature =
  let init =
    { latest = None
    ; last = None
    ; convertible = false
    ; sigitems = []
    ; extra_sigitems = []
    ; no_toplevel_latest = !no_toplevel_latest_type
    }
  in
  let f
      { latest
      ; last
      ; convertible
      ; sigitems
      ; extra_sigitems
      ; no_toplevel_latest
      } sigitem =
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
          convert_module_type pmd_type
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
        ; no_toplevel_latest
        }
    | Psig_attribute { attr_name; _ }
      when String.equal attr_name.txt "no_toplevel_latest_type" ->
        { latest
        ; last = None
        ; convertible
        ; sigitems
        ; extra_sigitems = []
        ; no_toplevel_latest = true
        }
    | _ ->
        Location.raise_errorf ~loc:sigitem.psig_loc
          "Expected versioned module declaration"
  in
  List.fold signature ~init ~f

let version_module_decl ~loc ~path:_ modname signature =
  Printexc.record_backtrace true ;
  try
    let open Ast_helper in
    let modname = map_loc ~f:(check_modname ~loc:modname.loc) modname in
    let { txt = { latest; sigitems; convertible; extra_sigitems; _ }; _ } =
      map_loc ~f:(convert_module_decls ~loc:signature.loc) signature
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
              [%sig:
                val versions :
                  ( int
                  * (Core_kernel.Bigstring.t -> pos_ref:int ref -> Latest.t) )
                  array

                val bin_read_to_latest_opt :
                  Bin_prot.Common.buf -> pos_ref:int ref -> Latest.t option]
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
  let module_extension_asserted =
    Extension.(
      declare "versioned_asserted" Context.structure_item module_ast_pattern
        (version_module ~version_option:Asserted))
  in
  let module_extension_binable =
    Extension.(
      declare "versioned_binable" Context.structure_item module_ast_pattern
        (version_module ~version_option:Binable))
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
  let module_rule_asserted =
    Context_free.Rule.extension module_extension_asserted
  in
  let module_rule_binable =
    Context_free.Rule.extension module_extension_binable
  in
  let module_decl_rule = Context_free.Rule.extension module_decl_extension in
  let rules =
    [ module_rule; module_rule_asserted; module_rule_binable; module_decl_rule ]
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
