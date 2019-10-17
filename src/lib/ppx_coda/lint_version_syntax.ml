(* lint_version_syntax.ml -- static enforcement of syntactic items relating to proper versioning

   - "deriving bin_io" and "deriving version" never appear in types defined inside functor bodies
   - otherwise, "bin_io" may appear in a "deriving" attribute only if "version" also appears in that extension

*)

open Core_kernel
open Ppxlib

let name = "enforce_version_syntax"

let errors_as_warnings_ref = ref false

let is_ident ident item =
  let version_id id =
    match id.txt with Lident s -> String.equal s ident | _ -> false
  in
  match item with
  | Pexp_ident id ->
      version_id id
  | Pexp_apply ({pexp_desc= Pexp_ident id; _}, _) ->
      version_id id
  | _ ->
      false

let payload_has_item is_item_ident payload =
  match payload with
  | PStr structure ->
      List.exists structure ~f:(fun str ->
          match str.pstr_desc with
          | Pstr_eval (expr, _) -> (
            (* the "ident" can appear as a singleton ident, or in a tuple *)
            match expr.pexp_desc with
            | Pexp_ident _ ->
                is_item_ident expr.pexp_desc
            | Pexp_apply ({pexp_desc; _}, _) ->
                is_item_ident pexp_desc
            | Pexp_tuple items ->
                List.exists items ~f:(fun item -> is_item_ident item.pexp_desc)
            | _ ->
                false )
          | _ ->
              false )
  | _ ->
      false

let is_version_ident = is_ident "version"

let payload_has_version = payload_has_item is_version_ident

let is_bin_io_ident = is_ident "bin_io"

let payload_has_bin_io = payload_has_item is_bin_io_ident

let attribute_has_deriving_version ((name, payload) : attribute) =
  String.equal name.txt "deriving" && payload_has_version payload

let attributes_have_deriving_version (attrs : attribute list) =
  List.exists attrs ~f:attribute_has_deriving_version

let type_has_deriving_version type_decl =
  attributes_have_deriving_version type_decl.ptype_attributes

let is_deriving name = String.equal name "deriving"

let make_deriving_validator ~pred err_msg type_decl =
  let get_deriving_error (name, payload) =
    if is_deriving name.txt then
      let has_bin_io = payload_has_bin_io payload in
      let has_version = payload_has_version payload in
      if pred has_bin_io has_version then Some (name.loc, err_msg) else None
    else None
  in
  List.filter_map type_decl.ptype_attributes ~f:get_deriving_error

let validate_neither_bin_io_nor_version =
  make_deriving_validator
    ~pred:(fun has_bin_io has_version -> has_bin_io || has_version)
    "Deriving bin_io and deriving version disallowed for types in functor body"

let validate_version_if_bin_io =
  make_deriving_validator
    ~pred:(fun has_bin_io has_version -> has_bin_io && not has_version)
    "Must have deriving version if deriving bin_io"

let is_stable_latest_inc_decl inc_decl =
  match inc_decl.pincl_mod.pmod_desc with
  | Pmod_ident {txt= Ldot (Lident "Stable", "Latest"); _} ->
      true
  | _ ->
      false

let versioned_in_functor_error loc =
  (loc, "Cannot use versioned extension within a functor body")

let include_stable_latest_error loc =
  (loc, "Cannot use \"include Stable.Latest\"")

(* traverse AST, collect errors *)
let check_deriving_usage =
  object (self)
    (* bool indicates whether we're in a functor *)
    inherit [bool * (Location.t * string) list] Ast_traverse.fold as super

    method! module_expr expr ((in_functor, errors) as acc) =
      match expr.pmod_desc with
      (* don't match special case of functor with () argument *)
      | Pmod_functor (_label, Some _mty, body) ->
          let _, errs = self#module_expr body (true, errors) in
          (in_functor, errs)
      | _ ->
          super#module_expr expr acc

    method! structure_item str ((in_functor, errors) as acc) =
      match str.pstr_desc with
      | Pstr_type (_rec_decl, type_decls) ->
          (* for type declaration, check attributes *)
          let f =
            if in_functor then validate_neither_bin_io_nor_version
            else validate_version_if_bin_io
          in
          (in_functor, errors @ List.concat_map type_decls ~f)
      | Pstr_extension ((name, _payload), _attrs)
        when in_functor && String.equal name.txt "versioned" ->
          (in_functor, errors @ [versioned_in_functor_error name.loc])
      | Pstr_extension ((name, _payload), _attrs)
        when String.equal name.txt "test_module" ->
          (* don't check for errors in test code *)
          acc
      | Pstr_include inc_decl when is_stable_latest_inc_decl inc_decl ->
          (in_functor, errors @ [include_stable_latest_error str.pstr_loc])
      | _ ->
          super#structure_item str acc
  end

let enforce_deriving_usage str =
  let _in_functor, errors = check_deriving_usage#structure str (false, []) in
  if !errors_as_warnings_ref then (
    (* we can't print Lint_error.t's, so collect the same information
     in a way we can print, that is, a list of location, string pairs *)
    List.iter errors ~f:(fun (loc, msg) ->
        eprintf "File \"%s\", line %d, characters %d-%d:\n%!"
          loc.loc_start.pos_fname loc.loc_start.pos_lnum
          (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
          (loc.loc_end.pos_cnum - loc.loc_start.pos_bol) ;
        eprintf "Warning: %s\n%!" msg ) ;
    (* don't return errors *)
    [] )
  else
    (* produce Lint_error.t list from collected errors *)
    List.map errors ~f:(fun (loc, msg) -> Driver.Lint_error.of_string loc msg)

let () =
  Driver.add_arg "-lint-version-syntax-warnings"
    (Caml.Arg.Set errors_as_warnings_ref)
    ~doc:" Version syntax errors as warnings" ;
  Ppxlib.Driver.register_transformation name ~lint_impl:enforce_deriving_usage
