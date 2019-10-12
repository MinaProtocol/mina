(* lint_syntax.ml -- static enforcement of syntactic items relating to proper versioning

   - "deriving bin_io" never appears in types defined inside functor bodies
   - otherwise, "bin_io" may appear in a "deriving" attribute iff "version" appears in that extension

*)

open Core_kernel
open Ppxlib

let name = "enforce_syntax"

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

let is_version_ident = is_ident "version"

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

let validate_no_bin_io_or_version =
  make_deriving_validator
    ~pred:(fun has_bin_io has_version -> has_bin_io || has_version)
    "deriving bin_io and deriving version disallowed for types in functor body"

let validate_bin_io_and_version =
  make_deriving_validator
    ~pred:(fun has_bin_io has_version ->
      not @@ Bool.equal has_bin_io has_version )
    "Must have both deriving bin_io and deriving version, or neither"

(* traverse AST, collect errors *)
let check_deriving_usage =
  object (self)
    (* bool indicates whether we're in a functor *)
    inherit [bool * (Location.t * string) list] Ast_traverse.fold as super

    method get_structure_errors str in_functor =
      let result =
        List.map str ~f:(fun si -> self#structure_item si (in_functor, []))
      in
      List.concat @@ List.map result ~f:snd

    (* in_functor flows down the tree as we examine subtrees, so we need its value
       _errors flow up the tree, so we can ignore the passed-in value
    *)
    method! structure_item str ((in_functor, _errors) as acc) =
      match str.pstr_desc with
      | Pstr_module {pmb_expr; pmb_name; _} -> (
        match pmb_expr.pmod_desc with
        | Pmod_structure structure ->
            (* generated With_version module has deriving bin_io, but not version *)
            if String.equal pmb_name.txt "With_version" then (in_functor, [])
            else (in_functor, self#get_structure_errors structure in_functor)
        | Pmod_functor (_name, _mod_type_opt, mod_expr) ->
            let rec functor_body_errors mod_exp =
              match mod_exp.pmod_desc with
              | Pmod_structure str ->
                  self#get_structure_errors str true
              | Pmod_functor (_, _, mod_expr') ->
                  functor_body_errors mod_expr'
              | Pmod_apply (mod_expr1, mod_expr2) ->
                  functor_body_errors mod_expr1 @ functor_body_errors mod_expr2
              | _ ->
                  Location.raise_errorf ~loc:mod_exp.pmod_loc
                    "Don't know how to analyze this functor body"
            in
            (in_functor, functor_body_errors mod_expr)
        | _ ->
            acc )
      | Pstr_type (_rec_decl, type_decls) ->
          (* for type declaration, check attributes *)
          let f =
            if in_functor then validate_no_bin_io_or_version
            else validate_bin_io_and_version
          in
          (in_functor, List.concat @@ List.map type_decls ~f)
      | Pstr_extension ((name, _payload), _attrs)
        when String.equal name.txt "test_module" ->
          (* don't check for errors in test code *)
          acc
      | _ ->
          super#structure_item str acc
  end

let enforce_deriving_usage str =
  let _in_functor, errors = check_deriving_usage#structure str (false, []) in
  (* we can't print Lint_error.t's, so collect the same information
     in a way we can print, that is, a list of location, string pairs *)
  List.iter errors ~f:(fun (loc, msg) ->
      eprintf "File \"%s\", line %d, characters %d-%d:\n%!"
        loc.loc_start.pos_fname loc.loc_start.pos_lnum
        (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
        (loc.loc_end.pos_cnum - loc.loc_start.pos_bol) ;
      eprintf "Error: %s\n%!" msg ) ;
  let exit_code = if List.is_empty errors then 0 else 1 in
  (* use conditional to prevent compile error *)
  if true then Stdlib.exit exit_code ;
  (* don't actually return anything *)
  []

let register () =
  Ppxlib.Driver.register_transformation name ~lint_impl:enforce_deriving_usage
