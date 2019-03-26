(* versioned.ml -- static enforcement of versioned types via ppx

   1) check that versioned type always in Stable.Vn.T module hierarchy
   2) versioned types depend only on other versioned types (or OCaml built-in types)

  to use, add coda_ppx to the dune pps list, and add "versioned" to deriving list for a type

 *)

open Core_kernel
open Ppxlib

let is_versioned_ident item =
  match item with
  | Pexp_ident id -> (
    match id.txt with Lident s -> String.equal s "versioned" | _ -> false )
  | _ -> false

let payload_has_versioned payload =
  match payload with
  | PStr structure ->
      List.exists structure ~f:(fun str ->
          match str.pstr_desc with
          | Pstr_eval (expr, _) -> (
            (* the "versioned" can appear as a singleton ident, or in a tuple *)
            match expr.pexp_desc with
            | Pexp_ident _ -> is_versioned_ident expr.pexp_desc
            | Pexp_tuple items ->
                List.exists items ~f:(fun item ->
                    is_versioned_ident item.pexp_desc )
            | _ -> false )
          | _ -> false )
  | _ -> false

let attribute_has_deriving_versioned ((name, payload) : attribute) =
  String.equal name.txt "deriving" && payload_has_versioned payload

let attributes_have_deriving_versioned (attrs : attribute list) =
  List.exists attrs ~f:attribute_has_deriving_versioned

let type_has_deriving_versioned type_decl =
  attributes_have_deriving_versioned type_decl.ptype_attributes

(* check that a versioned type occurs in valid module hierarchy and is named "t" *)
let validate_versioned type_decl inner3_modules =
  if type_has_deriving_versioned type_decl then (
    if not (String.equal type_decl.ptype_name.txt "t") then
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type must be named \"t\", got: \"%s\""
        type_decl.ptype_name.txt ;
    match inner3_modules with
    | ["T"; version_module; "Stable"] ->
        let len = String.length version_module in
        if (not (Char.equal version_module.[0] 'V')) && len > 1 then
          Location.raise_errorf ~loc:type_decl.ptype_loc
            "Versioning module containing versioned type must be named Vn, \
             for some number n"
        else
          let numeric_part = String.sub version_module ~pos:1 ~len:(len - 1) in
          String.iter numeric_part ~f:(fun c ->
              if not (Char.is_digit c) then
                Location.raise_errorf ~loc:type_decl.ptype_loc
                  "Versioning module name must be Vn, for some number n, got: \
                   \"%s\""
                  version_module ) ;
          (* invariant: 0th char is digit *)
          if Int.equal (Char.get_digit_exn numeric_part.[0]) 0 then
            Location.raise_errorf ~loc:type_decl.ptype_loc
              "Versioning module name must be Vn, for a number n, but n \
               cannot begin with 0, got: \"%s\""
              version_module
    | _ ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type must be contained in module structure Stable.Vn.T, \
           for some number n" )

(* traverse AST *)
let versioned_syntactic_check =
  object (self)
    inherit [string list] Ast_traverse.fold_map as super

    (* acc is list of module names traversed, from innermost to outer *)
    method! structure_item str acc =
      match str.pstr_desc with
      (* for modules, current name is cons'ed to acc *)
      | Pstr_module ({pmb_name; pmb_expr; _} as module_details) -> (
        match pmb_expr.pmod_desc with
        | Pmod_structure structure ->
            let new_acc = pmb_name.txt :: acc in
            let results =
              List.map structure ~f:(fun si -> self#structure_item si new_acc)
            in
            let _new_pmb_expr, _modules = List.unzip results in
            (* TODO : do the deriving *)
            let new_str =
              {pstr_desc= Pstr_module module_details; pstr_loc= str.pstr_loc}
            in
            (new_str, acc)
        | _ -> (str, acc) )
      (* for type declaration, check validity when versioned *)
      | Pstr_type (_rec_decl, type_decls) ->
          let inner3_modules = List.take acc 3 in
          List.iter type_decls ~f:(fun ty_decl ->
              validate_versioned ty_decl inner3_modules ) ;
          (str, acc)
      | _ -> super#structure_item str acc
  end

let versioned_module structure =
  let new_structure, _acc = versioned_syntactic_check#structure structure [] in
  new_structure

let () =
  Driver.register_transformation "versioned_module" ~impl:versioned_module
