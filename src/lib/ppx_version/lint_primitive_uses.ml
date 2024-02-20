open! Core_kernel
open Ppxlib

let error which loc =
  Location.raise_errorf ~loc
    "Type declarations with deriving bin_io or versioning should not use the \
     '%s' type. Use 'Bounded_types.%s.Stable.V1.t' instead."
    which (String.capitalize which)

let has_deriving_extension_with_attrs (attrs : attributes) =
  List.exists attrs ~f:(fun attr ->
      match attr with
      | { attr_name = { txt = "deriving"; _ }; attr_payload = PStr str; _ } ->
          List.exists str ~f:(fun item ->
              match item.pstr_desc with
              | Pstr_eval ({ pexp_desc; _ }, _) ->
                  let rec find_in_expr = function
                    | Pexp_ident { txt = Lident "bin_io" | Lident "version"; _ }
                      ->
                        true
                    | Pexp_tuple exps ->
                        List.exists exps ~f:(fun exp ->
                            find_in_expr exp.pexp_desc )
                    | _ ->
                        false
                  in
                  find_in_expr pexp_desc
              | _ ->
                  false )
      | _ ->
          false )

let check_type_definition module_binding =
  match module_binding with
  | { pmb_expr = { pmod_desc = Pmod_structure structure; _ }; _ } ->
      List.iter structure ~f:(fun item ->
          match item with
          | [%stri
              type t =
                [%t?
                  { ptyp_desc =
                      Ptyp_constr
                        ({ txt = Longident.Lident ("array" as nm); _ }, _)
                  ; _
                  }]]
          | [%stri
              type t =
                [%t?
                  { ptyp_desc =
                      Ptyp_constr
                        ({ txt = Longident.Lident ("bigstring" as nm); _ }, _)
                  ; _
                  }]]
          | [%stri
              type t =
                [%t?
                  { ptyp_desc =
                      Ptyp_constr
                        ({ txt = Longident.Lident ("bytes" as nm); _ }, _)
                  ; _
                  }]]
          | [%stri
              type t =
                [%t?
                  { ptyp_desc =
                      Ptyp_constr
                        ({ txt = Longident.Lident ("string" as nm); _ }, _)
                  ; _
                  }]] ->
              (* Raise an error when type 't' uses an unsafe type above. *)
              error nm item.pstr_loc
          | _ ->
              () )
  | _ ->
      ()

let find_array_in_type_declaration decl =
  let rec check_array_type { ptyp_desc; _ } =
    match ptyp_desc with
    | Ptyp_constr ({ txt = Lident ("string" as nm); loc }, _)
    | Ptyp_constr ({ txt = Lident ("bytes" as nm); loc }, _)
    | Ptyp_constr ({ txt = Lident ("bigstring" as nm); loc }, _)
    | Ptyp_constr ({ txt = Lident ("array" as nm); loc }, _) ->
        error nm loc
    | Ptyp_constr (_, core_types) | Ptyp_tuple core_types ->
        List.iter core_types ~f:check_array_type
    | Ptyp_variant (rows, _, _) ->
        List.iter rows ~f:(fun { prf_desc; _ } ->
            match prf_desc with
            | Rtag (_, _, typs) ->
                List.iter typs ~f:check_array_type
            | Rinherit typ ->
                check_array_type typ )
    | Ptyp_any
    | Ptyp_var _
    | Ptyp_arrow (_, _, _)
    | Ptyp_object (_, _)
    | Ptyp_class (_, _)
    | Ptyp_alias (_, _)
    | Ptyp_poly (_, _)
    | Ptyp_package _
    | Ptyp_extension _ ->
        ()
  in
  match decl.ptype_kind with
  | Ptype_abstract | Ptype_open ->
      ()
  | Ptype_variant decls ->
      List.iter decls ~f:(fun decl ->
          match decl.pcd_args with
          | Pcstr_tuple types ->
              List.iter types ~f:(fun typ -> check_array_type typ)
          | Pcstr_record labels ->
              List.iter labels ~f:(fun label ->
                  check_array_type label.pld_type ) )
  | Ptype_record labels ->
      List.iter labels ~f:(fun label -> check_array_type label.pld_type)

let versionedArrayTypeCheckerInsideVxModule =
  object
    inherit Ast_traverse.iter as super

    method! type_declaration decl =
      if String.equal decl.ptype_name.txt "t" then
        find_array_in_type_declaration decl ;
      super#type_declaration decl
  end

let versionedArrayTypeChecker =
  object
    inherit [Driver.Lint_error.t list] Ast_traverse.fold as super

    method! type_declaration decl acc =
      if has_deriving_extension_with_attrs decl.ptype_attributes then
        find_array_in_type_declaration decl ;
      super#type_declaration decl acc

    (* Override the module declaration handling *)
    method! extension extension acc =
      ( match extension with
      | { txt = "versioned"; _ }, PStr [ { pstr_desc; _ } ] -> (
          match pstr_desc with
          | Pstr_module
              { pmb_name = { txt = Some "Stable"; _ }
              ; pmb_expr = { pmod_desc = Pmod_structure l; _ }
              ; _
              } ->
              List.iter l ~f:(fun { pstr_desc; _ } ->
                  match pstr_desc with
                  | Pstr_module
                      { pmb_expr = { pmod_desc = Pmod_structure structure; _ }
                      ; _
                      } ->
                      List.iter structure ~f:(fun { pstr_desc; _ } ->
                          match pstr_desc with
                          | Pstr_type (_, type_declarations) ->
                              List.iter type_declarations ~f:(fun decl ->
                                  if String.equal decl.ptype_name.txt "t" then
                                    find_array_in_type_declaration decl )
                          | Pstr_module
                              { pmb_name = { txt = Some "T"; _ }
                              ; pmb_expr =
                                  { pmod_desc = Pmod_structure structure; _ }
                              ; _
                              } ->
                              versionedArrayTypeCheckerInsideVxModule#structure
                                structure
                          | _ ->
                              () )
                  | _ ->
                      () )
          | _ ->
              () )
      | _ ->
          () ) ;
      super#extension extension acc
  end

let () =
  Driver.register_transformation
    ~lint_impl:(fun st -> versionedArrayTypeChecker#structure st [])
    "enforce_bounded_array"
