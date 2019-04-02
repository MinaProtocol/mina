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
  if wrapped then validate_wrapped_type_decl inner3_modules type_decl
  else validate_unwrapped_type_decl inner3_modules type_decl

let module_name_from_unwrapped_path inner3_modules =
  match inner3_modules with
  | ["T"; module_version; "Stable"] -> module_version
  | _ -> failwith "module_name_from_unwrapped_path: unexpected module path"

let module_name_from_wrapped_path inner3_modules =
  match inner3_modules with
  | [module_version; "Stable"; "Wrapped"] -> module_version
  | _ -> failwith "module_name_from_wrapped_path: unexpected module path"

(* generate "let version = n", when version module is Vn *)
let generate_version_number_decl inner3_modules loc wrapped =
  (* invariant: we've checked module name already *)
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let module_name =
    if wrapped then module_name_from_wrapped_path inner3_modules
    else module_name_from_unwrapped_path inner3_modules
  in
  let version =
    String.sub module_name ~pos:1 ~len:(String.length module_name - 1)
    |> int_of_string
  in
  [%stri let version = [%e eint version]]

let ocaml_builtin_types = ["int"; "float"; "char"; "string"; "bool"; "unit"]

let ocaml_builtin_type_constructors = ["list"; "option"; "ref"]

let rec generate_core_type_version_decls core_type =
  match core_type.ptyp_desc with
  | Ptyp_constr ({txt; _}, core_types) -> (
    match txt with
    | Lident id ->
        (* type t = id *)
        if
          List.is_empty core_types
          && List.mem ocaml_builtin_types id ~equal:String.equal
        then (* no versioning to worry about *)
          []
        else if List.mem ocaml_builtin_type_constructors id ~equal:String.equal
        then
          match core_types with
          | [_] -> generate_version_lets_for_core_types core_types
          | _ ->
              Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
                "Type constructor \"%s\" expects one type argument, got %d" id
                (List.length core_types)
        else
          (* a type not in a module (so not versioned) *)
          Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
            "Type \"%s\" is not a versioned type" id
    | Ldot (prefix, "t") ->
        (* type t = A.B.t
          generate: let _ = A.B.__versioned__
        *)
        let loc = core_type.ptyp_loc in
        let pexp_loc = loc in
        let versioned_ident =
          { pexp_desc= Pexp_ident {txt= Ldot (prefix, "__versioned__"); loc}
          ; pexp_loc
          ; pexp_attributes= [] }
        in
        [%str let _ = [%e versioned_ident]]
        @ generate_version_lets_for_core_types core_types
    | _ ->
        Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
          "Unrecognized type constructor for versioned type" )
  | Ptyp_tuple core_types ->
      (* type t = t1 * t2 * t3 *)
      generate_version_lets_for_core_types core_types
  | Ptyp_variant _ -> (* type t = [ `A | `B ] *)
                      []
  | Ptyp_var _ -> (* type variable *)
                  []
  | _ ->
      Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
        "Can't determine versioning for contained type"

and generate_version_lets_for_core_types core_types =
  List.fold_right core_types ~init:[] ~f:(fun core_type accum ->
      generate_core_type_version_decls core_type @ accum )

let generate_version_lets_for_label_decls label_decls =
  generate_version_lets_for_core_types
    (List.map label_decls ~f:(fun lab_decl -> lab_decl.pld_type))

let generate_constructor_decl_decls ctor_decl =
  match (ctor_decl.pcd_res, ctor_decl.pcd_args) with
  | None, Pcstr_tuple core_types ->
      (* C of T1 * ... * Tn *)
      generate_version_lets_for_core_types core_types
  | None, Pcstr_record label_decls ->
      (* C of { ... } *)
      generate_version_lets_for_label_decls label_decls
  | _ ->
      Ppx_deriving.raise_errorf ~loc:ctor_decl.pcd_loc
        "Can't determine versioning for constructor declaration"

let generate_contained_type_decls type_decl =
  match type_decl.ptype_kind with
  | Ptype_abstract ->
      if Option.is_none type_decl.ptype_manifest then
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type, not a label or variant, must have manifest \
           (right-hand side)" ;
      let manifest = Option.value_exn type_decl.ptype_manifest in
      generate_core_type_version_decls manifest
  | Ptype_variant ctor_decls ->
      List.fold ctor_decls ~init:[] ~f:(fun accum ctor_decl ->
          generate_constructor_decl_decls ctor_decl @ accum )
  | Ptype_record label_decls ->
      generate_version_lets_for_label_decls label_decls
  | Ptype_open ->
      Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type must not be open"

let generate_versioned_decls type_decl wrapped =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = type_decl.ptype_loc
  end) in
  let open E in
  let versioned_current = [%stri let __versioned__ = true] in
  if wrapped then [versioned_current]
  else versioned_current :: generate_contained_type_decls type_decl

let get_type_decl_representative type_decls =
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
  type_decl1

let generate_let_bindings_for_type_decl_str ~options ~path type_decls =
  let type_decl = get_type_decl_representative type_decls in
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
  validate_type_decl inner3_modules wrapped type_decl ;
  generate_version_number_decl inner3_modules type_decl.ptype_loc wrapped
  :: generate_versioned_decls type_decl wrapped

let generate_val_decls_for_type_decl type_decl =
  match type_decl.ptype_kind with
  (* the structure of the type doesn't affect what we generate for signatures *)
  | Ptype_abstract | Ptype_variant _ | Ptype_record _ ->
      let loc = type_decl.ptype_loc in
      [%sig:
        val version : int

        val __versioned__ : bool]
  | Ptype_open ->
      (* but the type can't be open, else it might vary over time *)
      Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type in a signature must not be open"

let generate_val_decls_for_type_decl_sig ~options:_ ~path:_ type_decls =
  (* in a signature, the module path may vary *)
  let type_decl = get_type_decl_representative type_decls in
  generate_val_decls_for_type_decl type_decl

let () =
  Ppx_deriving.(
    register
      (create deriver ~type_decl_str:generate_let_bindings_for_type_decl_str
         ~type_decl_sig:generate_val_decls_for_type_decl_sig ()))
