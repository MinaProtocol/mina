open Core_kernel
open Ppxlib

let mk_loc ~loc txt = {Location.loc; txt}

let map_loc ~f {Location.loc; txt} = {Location.loc; txt= f txt}

let parse_opt = Ast_pattern.parse ~on_error:(fun () -> None)

(* TODO: Check if we need to optcomp this for 4.08 support. *)
(*
let create_attr ~loc attr_name attr_payload =
  {Parsetree.attr_name; attr_payload; attr_loc= loc}

let modify_attr_payload attr attr_payload =
  {attr with Parsetree.attr_payload}
*)
let create_attr ~loc:_ name payload = (name, payload)

let modify_attr_payload (name, _) payload = (name, payload)

let rec add_deriving ~loc attributes =
  let (module Ast_builder) = Ast_builder.make loc in
  let payload idents =
    let payload = Ast_builder.(pstr_eval (pexp_tuple idents) []) in
    PStr [payload]
  in
  match attributes with
  | [] ->
      let attr_name = mk_loc ~loc "deriving" in
      let attr_payload = payload [[%expr bin_io]; [%expr version]] in
      [create_attr ~loc attr_name attr_payload]
  | attr :: attributes -> (
      let idents =
        Ast_pattern.(attribute (string "deriving") (single_expr_payload __))
      in
      match parse_opt idents loc attr (fun l -> Some l) with
      | None ->
          attr :: add_deriving ~loc attributes
      | Some args ->
          (* Can't use [Ast_pattern] here, because [alt] doesn't suppress the
             errors raised from the [pexp_*] patterns..
          *)
          let args =
            match args.pexp_desc with Pexp_tuple args -> args | _ -> [args]
          in
          let special_version =
            Ast_pattern.(
              pexp_apply (pexp_ident (lident (string "version"))) __)
          in
          if
            List.exists args ~f:(fun arg ->
                match parse_opt special_version loc arg (fun _ -> Some ()) with
                | None ->
                    false
                | Some () ->
                    true )
          then
            (* [version] is already present, add [bin_io] and stop recursing. *)
            modify_attr_payload attr (payload ([%expr bin_io] :: args))
            :: attributes
          else
            modify_attr_payload attr
              (payload ([%expr bin_io] :: [%expr version] :: args))
            :: attributes )

let version_type version stri =
  let loc = stri.pstr_loc in
  let t, params =
    (* NOTE: Can't use [Ast_pattern] here; it rejects attributes attached to
       types..
    *)
    match stri.pstr_desc with
    | Pstr_type
        ( rec_flag
        , [({ptype_name= {txt= "t"; _}; ptype_private= Public; _} as typ)] ) ->
        let params = typ.ptype_params in
        let typ =
          { typ with
            ptype_attributes=
              add_deriving ~loc:typ.ptype_loc typ.ptype_attributes }
        in
        let t = {stri with pstr_desc= Pstr_type (rec_flag, [typ])} in
        (t, params)
    | _ ->
        (* TODO: Handle rpc types. *)
        Location.raise_errorf ~loc "Expected a single public type t."
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
      create_attr ~loc (Located.mk "deriving") (PStr [[%stri bin_io]])
    in
    let typ =
      {typ with ptype_attributes= t_deriving :: typ.ptype_attributes}
    in
    let t =
      type_declaration ~name:(Located.mk "t") ~params ~cstrs:[]
        ~private_:Public ~manifest:None
        ~kind:
          (Ptype_record
             [ label_declaration ~name:(Located.mk "version")
                 ~mutable_:Immutable
                 ~type_:(ptyp_constr (Located.lident "int") [])
             ; label_declaration ~name:(Located.mk "t") ~mutable_:Immutable
                 ~type_:
                   (ptyp_constr (Located.lident "typ") (List.map ~f:fst params))
             ])
    in
    let t = {t with ptype_attributes= t_deriving :: t.ptype_attributes} in
    let create = [%stri let create t = {t; version= [%e eint version]}] in
    pstr_module
      (module_binding
         ~name:(Located.mk "With_version")
         ~expr:
           (pmod_structure
              [pstr_type Recursive [typ]; pstr_type Recursive [t]; create]))
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
                  let With_version.{version= read_version; t} =
                    [%e apply_args [%expr With_version.bin_read_t]]
                      buf ~pos_ref
                  in
                  (* sanity check *)
                  assert (Int.equal read_version version) ;
                  t]]]
    ; [%stri
        let __bin_read_t__ =
          [%e
            fun_args
              [%expr
                fun buf ~pos_ref i ->
                  let With_version.{version= read_version; t} =
                    [%e apply_args [%expr With_version.__bin_read_t__]]
                      buf ~pos_ref i
                  in
                  (* sanity check *)
                  assert (Int.equal read_version version) ;
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
                { Bin_prot.Type_class.read=
                    [%e apply_args ~f:(mk_field "read") [%expr bin_read_t]]
                ; vtag_read=
                    [%e apply_args ~f:(mk_field "read") [%expr __bin_read_t__]]
                }]]]
    ; [%stri
        let bin_writer_t =
          [%e
            fun_args
              [%expr
                { Bin_prot.Type_class.size=
                    [%e apply_args ~f:(mk_field "size") [%expr bin_size_t]]
                ; write=
                    [%e apply_args ~f:(mk_field "write") [%expr bin_write_t]]
                }]]]
    ; [%stri
        let bin_t =
          [%e
            fun_args
              [%expr
                { Bin_prot.Type_class.shape=
                    [%e apply_args ~f:(mk_field "shape") [%expr bin_shape_t]]
                ; writer=
                    [%e apply_args ~f:(mk_field "writer") [%expr bin_writer_t]]
                ; reader=
                    [%e apply_args ~f:(mk_field "reader") [%expr bin_reader_t]]
                }]]]
    ; [%stri
        let _ =
          ( bin_read_t
          , __bin_read_t__
          , bin_size_t
          , bin_write_t
          , bin_shape_t
          , bin_reader_t
          , bin_writer_t
          , bin_t )] ]
  in
  (List.is_empty params, t :: with_version :: bin_io_shadows)

let convert_module_stri last_version stri =
  let module_pattern =
    Ast_pattern.(
      pstr_module (module_binding ~name:__' ~expr:(pmod_structure __')))
  in
  let loc = stri.pstr_loc in
  let name, str =
    Ast_pattern.parse module_pattern loc stri
      ~on_error:(fun () ->
        Location.raise_errorf ~loc
          "Expected a statement of the form `module Vn = struct ... end`." )
      (fun name str -> (name, str))
  in
  Versioned_type.validate_module_version name.txt name.loc ;
  let version =
    String.sub name.txt ~pos:1 ~len:(String.length name.txt - 1)
    |> int_of_string
  in
  Option.iter last_version ~f:(fun last_version ->
      if version = last_version then
        (* Mimic wording of the equivalent OCaml error. *)
        Location.raise_errorf ~loc
          "Multiple definition of the module name V%i." version
      else if version >= last_version then
        Location.raise_errorf ~loc
          "Versioned modules must be listed in decreasing order." ) ;
  let type_stri, str_rest =
    match str.txt with
    | [] ->
        Location.raise_errorf ~loc:str.loc
          "Expected a type declaration in this structure."
    | type_stri :: str ->
        (type_stri, str)
  in
  let should_convert, type_versioning_str = version_type version type_stri in
  (* TODO: If [should_convert] then look for [to_latest]. *)
  let open Ast_builder.Default in
  ( version
  , pstr_module ~loc
      (module_binding ~loc ~name
         ~expr:(pmod_structure ~loc:str.loc (type_versioning_str @ str_rest)))
  , should_convert )

let convert_modbody ~loc body =
  let may_convert_latest = ref None in
  let latest_version = ref None in
  let _, rev_str, convs =
    List.fold ~init:(None, [], []) body
      ~f:(fun (version, rev_str, convs) stri ->
        let version, stri, should_convert = convert_module_stri version stri in
        ( match !may_convert_latest with
        | None ->
            may_convert_latest := Some should_convert ;
            latest_version := Some version
        | Some _ ->
            () ) ;
        let convs = if should_convert then version :: convs else convs in
        (Some version, stri :: rev_str, convs) )
  in
  let (module Ast_builder) = Ast_builder.make loc in
  let rev_str =
    match !latest_version with
    | Some latest_version ->
        let open Ast_builder in
        let latest =
          pstr_module
            (module_binding ~name:(Located.mk "Latest")
               ~expr:
                 (pmod_ident (Located.lident (sprintf "V%i" latest_version))))
        in
        latest :: rev_str
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
                  (int * (Core_kernel.Bigstring.t -> Latest.t)) array) =
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
                             fun buf ->
                               let pos_ref = ref 0 in
                               [%e pexp_ident (dot "bin_read_t")] buf ~pos_ref
                               |> [%e pexp_ident (dot "to_latest")]] ] ))]]
        in
        let convert =
          [%stri
            (** deserializes data to the latest module version's type *)
            let deserialize_binary_opt buf =
              let open Core_kernel in
              let pos_ref = ref 0 in
              (* Rely on layout, assume that the first element of the record is
           the first data in the buffer.
        *)
              let version = Bin_prot.Std.bin_read_int ~pos_ref buf in
              Array.find_map versions ~f:(fun (i, f) ->
                  if Int.equal i version then Some (f buf) else None )]
        in
        let convert_guard = [%stri let _ = deserialize_binary_opt] in
        convert_guard :: convert :: versions :: rev_str
    | _ ->
        rev_str
  in
  List.rev rev_str

let check_modname ~loc name =
  if name = "Stable" then name
  else
    Location.raise_errorf ~loc
      "Expected a module named Stable, but got a module named %s." name

let version_module ~loc ~path:_ modname modbody =
  Printexc.record_backtrace true ;
  try
    let modname = map_loc ~f:(check_modname ~loc:modname.loc) modname in
    let modbody = map_loc ~f:(convert_modbody ~loc:modbody.loc) modbody in
    let open Ast_helper in
    Str.module_ ~loc
      (Mb.mk ~loc:modname.loc modname
         (Mod.structure ~loc:modbody.loc modbody.txt))
  with exn ->
    Format.(fprintf err_formatter "%s@." (Printexc.get_backtrace ())) ;
    raise exn

let () =
  let ast_pattern =
    Ast_pattern.(
      pstr
        ( pstr_module (module_binding ~name:__' ~expr:(pmod_structure __'))
        ^:: nil ))
  in
  let extension =
    Extension.(
      declare "versioned" Context.structure_item ast_pattern version_module)
  in
  let rule = Context_free.Rule.extension extension in
  let rules = [rule] in
  Driver.register_transformation "ppx_coda/versioned_module" ~rules
