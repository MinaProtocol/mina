(* versioned.ml -- static enforcement of versioned types via ppx

   1) check that versioned type always in valid module hierarchy
   2) versioned types depend only on other versioned types or OCaml built-in types

  to use, add coda_ppx to the dune pps list, and annotate a type declaration with
  either

    [@@deriving version]

  or

    [@@deriving version { wrapped }]


  If the "wrapped" option is omitted (the common case), the type must be named "t", 
  and its definition occurs in the module hierarchy "Stable.Vn.T", where n is a 
  positive integer.
  
  If "wrapped" is true, again, the type must be named "t", but the type
  definition occurs in the hierarchy "Wrapped.Stable.Vn", where n is a positive
  integer. TODO: Anything to say about registration, translation to a latest
  version for wrapped types?

*)

open Core_kernel
open Ppxlib

type version_info = {versioned: bool; wrapped: bool}

let deriver = "version"

let validate_module_version module_version loc =
  let len = String.length module_version in
  if not (Char.equal module_version.[0] 'V' && len > 1) then
    Location.raise_errorf ~loc
      "Versioning module containing versioned type must be named Vn, for some \
       number n"
  else
    let numeric_part = String.sub module_version ~pos:1 ~len:(len - 1) in
    String.iter numeric_part ~f:(fun c ->
        if not (Char.is_digit c) then
          Location.raise_errorf ~loc
            "Versioning module name must be Vn, for some number n, got: \"%s\""
            module_version ) ;
    (* invariant: 0th char is digit *)
    if Int.equal (Char.get_digit_exn numeric_part.[0]) 0 then
      Location.raise_errorf ~loc
        "Versioning module name must be Vn, for a number n, which cannot \
         begin with 0, got: \"%s\""
        module_version

let validate_unwrapped_type_decl inner3_modules type_decl =
  match inner3_modules with
  | ["T"; module_version; "Stable"] ->
      validate_module_version module_version type_decl.ptype_loc
  | _ ->
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type must be contained in module path Stable.Vn.T, for \
         some number n"

let validate_wrapped_type_decl inner3_modules type_decl =
  match inner3_modules with
  | [module_version; "Stable"; "Wrapped"] ->
      validate_module_version module_version type_decl.ptype_loc
  | _ ->
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Wrapped versioned type must be contained in module path \
         Wrapped.Stable.Vn, for some number n"

(* check that a versioned type occurs in valid module hierarchy and is named "t"
 *)
let validate_type_decl inner3_modules wrapped type_decl =
  if not (String.equal type_decl.ptype_name.txt "t") then
    Location.raise_errorf ~loc:type_decl.ptype_name.loc
      "Versioned type must be named \"t\", got: \"%s\""
      type_decl.ptype_name.txt ;
  if not (List.is_empty type_decl.ptype_params) then
    Location.raise_errorf ~loc:type_decl.ptype_loc
      "Versioned type must not have type parameters" ;
  if wrapped then validate_wrapped_type_decl inner3_modules type_decl
  else validate_unwrapped_type_decl inner3_modules type_decl

let generate_contained_type_decls _type_decl =
  (* TODO *)
  []

let generate_versioned_decls type_decl wrapped =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = type_decl.ptype_loc
  end) in
  let open E in
  let versioned_current = [%stri let __versioned__ = true] in
  if wrapped then [versioned_current]
  else versioned_current :: generate_contained_type_decls type_decl

let generate_val_decls_for_type_decl ~options ~path type_decls =
  let type_decl1 = List.hd_exn type_decls in
  let type_decl2 = List.hd_exn (List.rev type_decls) in
  ( if not (Int.equal (List.length type_decls) 1) then
    let loc =
      { loc_start= type_decl1.ptype_loc.loc_start
      ; loc_end= type_decl2.ptype_loc.loc_end
      ; loc_ghost= true }
    in
    Ppx_deriving.raise_errorf ~loc
      "Versioned type must be just one type \"t\", not a sequence of types" ) ;
  let wrapped =
    match options with
    | [] -> false
    | [("wrapped", {pexp_desc= Pexp_ident {txt= Lident "wrapped"; _}; _})] ->
        true
    | _ ->
        let exprs = List.map options ~f:snd in
        let {pexp_loc= loc1; _} = List.hd_exn exprs in
        let {pexp_loc= loc2; _} = List.hd_exn (List.rev exprs) in
        let loc =
          {loc_start= loc1.loc_start; loc_end= loc2.loc_end; loc_ghost= true}
        in
        Ppx_deriving.raise_errorf ~loc
          "Invalid option(s) to \"version\", can only be \"wrapped\""
  in
  let inner3_modules = List.take (List.rev path) 3 in
  validate_type_decl inner3_modules wrapped type_decl1 ;
  generate_versioned_decls type_decl1 wrapped

let () =
  Ppx_deriving.(
    register
      (create deriver ~type_decl_str:generate_val_decls_for_type_decl ()))
