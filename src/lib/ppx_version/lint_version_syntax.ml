(* lint_version_syntax.ml -- static enforcement of syntactic items relating to proper versioning

   - "deriving bin_io" and "deriving version" never appear in types defined inside functor bodies
   - otherwise, "bin_io" may appear in a "deriving" attribute only if "version" also appears in that extension
   - versioned types only appear in versioned type definitions
   - versioned type definitions appear only in %%versioned... extensions
   - packaged modules, like "(module Foo)", may not be stable-versioned (but allowed inside %%versioned for
       legitimate uses)
   - the constructs "include Stable.Latest" and "include Stable.Vn" are prohibited
   - uses of Binable.Of... and Bin_prot.Utils.Make_binable functors are always in stable-versioned modules,
       and always as an argument to "include"
   - restrictions are not enforced in inline tests and inline test modules
*)

open Core_kernel
open Ppxlib
open Versioned_util

let name = "enforce_version_syntax"

let errors_as_warnings_ref = ref false

let make_deriving_validator ~pred err_msg type_decl =
  let derivers =
    Ast_pattern.(
      attribute ~name:(string "deriving") ~payload:(single_expr_payload __))
  in
  match
    List.find_map type_decl.ptype_attributes ~f:(fun attr ->
        parse_opt derivers Location.none attr (fun l -> Some l) )
  with
  | Some derivers ->
      let derivers_loc = derivers.pexp_loc in
      let derivers =
        match derivers.pexp_desc with
        | Pexp_tuple derivers ->
            derivers
        | _ ->
            [ derivers ]
      in
      let make_lident_pattern nm =
        Ast_pattern.(pexp_ident (lident (string nm)))
      in
      let version_pattern = make_lident_pattern "version" in
      let version_with_arg_pattern =
        Ast_pattern.(pexp_apply (make_lident_pattern "version") __)
      in
      let bin_io_pattern = make_lident_pattern "bin_io" in
      let make_find_pattern handler pat =
        List.exists derivers ~f:(fun deriver ->
            Option.is_some @@ parse_opt pat Location.none deriver handler )
      in
      let find_pattern = make_find_pattern (Some ()) in
      let find_with_arg_pattern = make_find_pattern (fun _ -> Some ()) in
      let has_bin_io = find_pattern bin_io_pattern in
      let has_version =
        find_pattern version_pattern
        || find_with_arg_pattern version_with_arg_pattern
      in
      if pred has_bin_io has_version then [ (derivers_loc, err_msg) ] else []
  | None ->
      []

let validate_neither_bin_io_nor_version =
  make_deriving_validator
    ~pred:(fun has_bin_io has_version -> has_bin_io || has_version)
    "Deriving bin_io and deriving version disallowed for types in functor body"

let validate_version_if_bin_io =
  make_deriving_validator
    ~pred:(fun has_bin_io has_version -> has_bin_io && not has_version)
    "Must have deriving version if deriving bin_io"

let is_version_module vn =
  let len = String.length vn in
  len >= 2
  && Char.equal vn.[0] 'V'
  && (not @@ Char.equal vn.[1] '0')
  && String.for_all (String.sub vn ~pos:1 ~len:(len - 1)) ~f:Char.is_digit

let is_versioned_module_inc_decl inc_decl =
  match inc_decl.pincl_mod.pmod_desc with
  | Pmod_ident { txt = Ldot (Lident "Stable", name); _ }
    when is_version_module name ->
      true
  | _ ->
      false

let versioned_in_functor_error loc =
  (loc, "Cannot use versioned extension within a functor body")

let include_stable_latest_error loc = (loc, "Cannot include Stable.Latest")

type accumulator =
  { in_functor : bool
  ; in_include : bool
  ; in_versioned_ext : bool
  ; module_path : string list
  ; errors : (Location.t * string) list
  }

let acc_with_errors acc errors = { acc with errors }

let acc_with_accum_errors acc errors = { acc with errors = acc.errors @ errors }

let is_longident_with_id id = function
  | Lident s when String.equal id s ->
      true
  | Ldot (_lident, s) when String.equal id s ->
      true
  | _ ->
      false

let is_version_module vn =
  let len = String.length vn in
  len >= 2
  && Char.equal vn.[0] 'V'
  && (not @@ Char.equal vn.[1] '0')
  && String.for_all (String.sub vn ~pos:1 ~len:(len - 1)) ~f:Char.is_digit

let is_stable_prefix = is_longident_with_id "Stable"

let is_stable_latest_inc_decl inc_decl =
  match inc_decl.pincl_mod.pmod_desc with
  | Pmod_ident { txt = Ldot (Lident "Stable", "Latest"); _ } ->
      true
  | _ ->
      false

let is_jane_street_prefix prefix =
  match Longident.flatten_exn prefix with
  (* N.B.: Uuid is in core_kernel library, but not in Core_kernel module *)
  | core :: _
    when List.mem [ "Core_kernel"; "Core"; "Uuid" ] core ~equal:String.equal ->
      true
  | _ ->
      false

(* N.B.: most versioned modules are within "Stable" modules, but that's not true
   for modules in RPC type definitions, so we can't rely on that name
*)
let in_versioned_type_module module_path =
  match module_path with
  | "T" :: vn :: _
    when is_version_module vn
         (* this case will go away when all versioned modules have %%versioned *)
    ->
      true
  | vn :: _ when is_version_module vn ->
      true
  | _ ->
      false

let is_versioned_module_ident id =
  match id with
  | Ldot (prefix, vn) when is_version_module vn && is_stable_prefix prefix ->
      true
  | _ ->
      false

let is_versioned_module_lident = function
  | Ldot (prefix, vn)
    when is_version_module vn
         && (not @@ is_jane_street_prefix prefix)
         && is_stable_prefix prefix ->
      true
  | _ ->
      false

let is_versioned_type_lident = function
  | Ldot (Ldot (prefix, vn), "t")
    when is_versioned_module_lident (Ldot (prefix, vn)) ->
      true
  | Ldot (Ldot (Ldot (prefix, vn), "T"), "t")
    when is_versioned_module_lident (Ldot (prefix, vn)) ->
      (* this case goes away when all versioned types use %%versioned *)
      true
  | _ ->
      false

let rec core_types_misuses core_types =
  List.concat_map core_types ~f:get_core_type_versioned_type_misuses

and get_core_type_versioned_type_misuses core_type =
  match core_type.ptyp_desc with
  | Ptyp_arrow (_label, core_type1, core_type2) ->
      core_types_misuses [ core_type1; core_type2 ]
  | Ptyp_tuple core_types ->
      core_types_misuses core_types
  | Ptyp_constr (lident, core_types) ->
      let core_type_errors = core_types_misuses core_types in
      if is_versioned_type_lident lident.txt then
        let err =
          ( lident.loc
          , "Versioned type used outside a versioned type declaration" )
        in
        err :: core_type_errors
      else core_type_errors
  | Ptyp_object (fields, _closed_flag) ->
      let core_type_of_field field =
        match field.pof_desc with
        | Otag (_label, core_type) ->
            core_type
        | Oinherit core_type ->
            core_type
      in
      let core_types = List.map fields ~f:core_type_of_field in
      core_types_misuses core_types
  | Ptyp_class (_lident, core_types) ->
      core_types_misuses core_types
  | Ptyp_alias (core_type, _label) ->
      get_core_type_versioned_type_misuses core_type
  | Ptyp_variant (row_fields, _closed_flag, _labels_opt) ->
      let core_types_of_row_field field =
        match field.prf_desc with
        | Rtag (_label, _b, core_types) ->
            core_types
        | Rinherit core_type ->
            [ core_type ]
      in
      let core_types = List.concat_map row_fields ~f:core_types_of_row_field in
      core_types_misuses core_types
  | Ptyp_poly (_labels, core_type) ->
      get_core_type_versioned_type_misuses core_type
  | Ptyp_package (_module, type_constraints) ->
      let core_types =
        List.map type_constraints ~f:(fun (_ty, core_type) -> core_type)
      in
      core_types_misuses core_types
  | Ptyp_extension _ext ->
      []
  | Ptyp_any ->
      []
  | Ptyp_var _ ->
      []

let types_of_constructor_args args =
  match args with
  | Pcstr_tuple tys ->
      tys
  | Pcstr_record label_decls ->
      List.map label_decls ~f:(fun decl -> decl.pld_type)

let types_of_type_kind kind =
  match kind with
  | Ptype_abstract ->
      []
  | Ptype_variant cstr_decls ->
      List.concat_map cstr_decls ~f:(fun decl ->
          let args_types = types_of_constructor_args decl.pcd_args in
          match decl.pcd_res with
          | None ->
              args_types
          | Some ty ->
              ty :: args_types )
  | Ptype_record label_decls ->
      List.map label_decls ~f:(fun decl -> decl.pld_type)
  | Ptype_open ->
      []

let get_versioned_type_misuses type_decl =
  let params_types =
    List.map type_decl.ptype_params ~f:(fun (ty, _variance) -> ty)
  in
  let cstr_types =
    List.concat_map type_decl.ptype_cstrs ~f:(fun (ty1, ty2, _loc) ->
        [ ty1; ty2 ] )
  in
  let kind_types = types_of_type_kind type_decl.ptype_kind in
  let manifest_types = Option.to_list type_decl.ptype_manifest in
  List.concat_map
    (params_types @ cstr_types @ kind_types @ manifest_types)
    ~f:get_core_type_versioned_type_misuses

let include_versioned_module_error loc =
  (loc, "Cannot include a stable versioned module")

let in_stable_versioned_module module_path =
  match module_path with
  | vn :: "Stable" :: _ when is_version_module vn ->
      true
  (* this case goes away when explicit module registration is gone *)
  | "T" :: vn :: "Stable" :: _ when is_version_module vn ->
      true
  | _ ->
      false

(* traverse AST, collect errors *)
let lint_ast =
  object (self)
    inherit [accumulator] Ast_traverse.fold as super

    method! expression expr acc =
      match expr.pexp_desc with
      | Pexp_extension (_, PTyp core_type) ->
          (* misuses like [%bin_type_class: Foo.Stable.V1.t] *)
          let errs = get_core_type_versioned_type_misuses core_type in
          acc_with_accum_errors acc errs
      | Pexp_pack mod_expr -> (
          (* misuses like (module Foo.Stable.V1) *)
          match mod_expr.pmod_desc with
          | Pmod_ident id
            when (not acc.in_versioned_ext) && is_versioned_module_lident id.txt
            ->
              let err = (id.loc, "Versioned module cannot be packaged") in
              acc_with_accum_errors acc [ err ]
          | _ ->
              acc )
      | _ ->
          super#expression expr acc

    method! module_expr expr acc =
      let acc' =
        match expr.pmod_desc with
        (* don't match special case of functor with () argument *)
        | Pmod_functor (Named _, body) ->
            self#module_expr body { acc with in_functor = true }
        | Pmod_apply
            ( { pmod_desc =
                  Pmod_apply
                    ( { pmod_desc =
                          Pmod_ident
                            { txt = Ldot (Lident "Binable", of_binable); _ }
                      ; _
                      }
                    , { pmod_desc = Pmod_ident { txt = arg; _ }; _ } )
              ; pmod_loc
              ; _
              }
            , _ )
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
            let include_errors =
              if acc.in_include then []
              else
                [ ( pmod_loc
                  , sprintf
                      "Binable.%s application must be an argument to an include"
                      of_binable )
                ]
            in
            let path_errors =
              if in_stable_versioned_module acc.module_path then []
              else
                [ ( pmod_loc
                  , sprintf
                      "Binable.%s applied outside of stable-versioned module"
                      of_binable )
                ]
            in
            let arg_errors =
              if is_versioned_module_ident arg then []
              else
                [ ( pmod_loc
                  , sprintf
                      "First argument to Binable.%s must be a stable-versioned \
                       module"
                      of_binable )
                ]
            in
            acc_with_accum_errors acc (include_errors @ path_errors @ arg_errors)
        | Pmod_apply
            ( { pmod_desc =
                  Pmod_apply
                    ( { pmod_desc =
                          Pmod_ident
                            { txt = Ldot (Lident "Binable", of_binable); _ }
                      ; _
                      }
                    , _ )
              ; pmod_loc
              ; _
              }
            , _ )
          when List.mem
                 [ "Of_binable_with_uuid"
                 ; "Of_binable1_with_uuid"
                 ; "Of_binable2_with_uuid"
                 ; "Of_binable3_with_uuid"
                 ; "Of_stringable_with_uuid"
                 ; "Of_sexpable_with_uuid"
                 ]
                 of_binable ~equal:String.equal ->
            let errors =
              [ ( pmod_loc
                , sprintf
                    "Binable.%s application not allowed, serialization may be \
                     unstable"
                    of_binable )
              ]
            in
            acc_with_accum_errors acc errors
        | Pmod_apply
            ( { pmod_desc = Pmod_ident { txt = Ldot (Lident "Binable", ftor); _ }
              ; pmod_loc
              ; _
              }
            , _ )
          when List.mem
                 [ "Of_sexpable"; "Of_stringable" ]
                 ftor ~equal:String.equal ->
            let include_errors =
              if acc.in_include then []
              else
                [ ( pmod_loc
                  , sprintf
                      "Binable.%s application must be an argument to an include"
                      ftor )
                ]
            in
            let path_errors =
              if in_stable_versioned_module acc.module_path then []
              else
                [ ( pmod_loc
                  , sprintf
                      "Binable.%s applied outside of stable-versioned module"
                      ftor )
                ]
            in
            acc_with_accum_errors acc (include_errors @ path_errors)
        | Pmod_apply
            ( { pmod_desc =
                  Pmod_ident
                    { txt =
                        Ldot (Ldot (Lident "Bin_prot", "Utils"), "Make_binable")
                    ; _
                    }
              ; pmod_loc
              ; _
              }
            , _ ) ->
            let include_errors =
              if acc.in_include then []
              else
                [ ( pmod_loc
                  , "Bin_prot.Utils.Make_binable application must be an \
                     argument to an include" )
                ]
            in
            let path_errors =
              if in_stable_versioned_module acc.module_path then []
              else
                [ ( pmod_loc
                  , "Bin_prot.Utils.Make_binable applied outside of \
                     stable-versioned module" )
                ]
            in
            acc_with_accum_errors acc (include_errors @ path_errors)
        | _ ->
            super#module_expr expr acc
      in
      acc_with_errors acc acc'.errors

    method! structure_item str acc =
      match str.pstr_desc with
      | Pstr_module { pmb_name = { txt = Some name; _ }; pmb_expr; _ } ->
          let acc' =
            self#module_expr pmb_expr
              { acc with module_path = name :: acc.module_path }
          in
          acc_with_errors acc acc'.errors
      | Pstr_type (rec_flag, type_decls) ->
          let no_errors_fun _type_decl = [] in
          let not_in_versioned_ext_fun type_decl =
            let ty_name = type_decl.ptype_name.txt in
            let err =
              ( type_decl.ptype_loc
              , "Versioned type must be in %%versioned extension" )
            in
            (* don't enforce %%versioned requirement for query, response types *)
            if String.equal ty_name "t" then [ err ] else []
          in
          let deriving_errors_fun =
            match rec_flag with
            | Nonrecursive ->
                no_errors_fun
            | Recursive ->
                if acc.in_functor then validate_neither_bin_io_nor_version
                else validate_version_if_bin_io
          in
          let versioned_type_misuse_errors_fun =
            if not @@ in_versioned_type_module acc.module_path then
              get_versioned_type_misuses
            else if not acc.in_versioned_ext then not_in_versioned_ext_fun
            else no_errors_fun
          in
          let deriving_errors =
            List.concat_map type_decls ~f:deriving_errors_fun
          in
          let versioned_type_misuse_errors =
            List.concat_map type_decls ~f:versioned_type_misuse_errors_fun
          in
          acc_with_accum_errors acc
            (deriving_errors @ versioned_type_misuse_errors)
      | Pstr_extension ((name, _payload), _attrs)
      (* %%versioned, %%versioned_asserted, etc. inside functor *)
        when acc.in_functor
             && String.length name.txt >= 9
             && String.equal (String.sub name.txt ~pos:0 ~len:9) "versioned" ->
          acc_with_accum_errors acc [ versioned_in_functor_error name.loc ]
      | Pstr_extension ((name, PStr [ stri ]), _attrs)
        when String.length name.txt >= 9
             && String.equal (String.sub name.txt ~pos:0 ~len:9) "versioned" ->
          let acc' =
            self#structure_item stri { acc with in_versioned_ext = true }
          in
          { acc' with in_versioned_ext = false }
      | Pstr_extension ((name, _payload), _attrs)
        when List.mem
               [ "test"; "test_unit"; "test_module" ]
               name.txt ~equal:String.equal ->
          (* don't check for errors in test code *)
          acc
      | Pstr_include inc_decl when is_stable_latest_inc_decl inc_decl ->
          acc_with_errors acc [ include_stable_latest_error str.pstr_loc ]
      | Pstr_include inc_decl when is_versioned_module_inc_decl inc_decl ->
          acc_with_errors acc [ include_versioned_module_error str.pstr_loc ]
      | Pstr_include inc_decl when is_stable_latest_inc_decl inc_decl ->
          acc_with_errors acc [ include_stable_latest_error str.pstr_loc ]
      | Pstr_include inc_decl ->
          let acc' =
            self#module_expr inc_decl.pincl_mod { acc with in_include = true }
          in
          { acc' with in_include = false }
      | _ ->
          let acc' = super#structure_item str acc in
          acc_with_errors acc acc'.errors
  end

let lint_impl str =
  let acc =
    lint_ast#structure str
      { in_functor = false
      ; in_include = false
      ; in_versioned_ext = false
      ; module_path = []
      ; errors = []
      }
  in
  if !errors_as_warnings_ref then (
    (* we can't print Lint_error.t's, so collect the same information
       in a way we can print, that is, a list of location, string pairs *)
    List.iter acc.errors ~f:(fun (loc, msg) ->
        eprintf "File \"%s\", line %d, characters %d-%d:\n%!"
          loc.loc_start.pos_fname loc.loc_start.pos_lnum
          (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
          (loc.loc_end.pos_cnum - loc.loc_start.pos_bol) ;
        eprintf "Warning: %s\n%!" msg ) ;
    (* don't return errors *)
    [] )
  else
    (* produce Lint_error.t list from collected errors *)
    List.map acc.errors ~f:(fun (loc, msg) ->
        Driver.Lint_error.of_string loc msg )

let () =
  Driver.add_arg "-lint-version-syntax-warnings"
    (Caml.Arg.Set errors_as_warnings_ref)
    ~doc:" Version syntax errors as warnings" ;
  Ppxlib.Driver.register_transformation name ~lint_impl
