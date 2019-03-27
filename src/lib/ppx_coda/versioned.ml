(* versioned.ml -- static enforcement of versioned types via ppx

   1) check that versioned type always in Stable.Vn.T module hierarchy
   2) versioned types depend only on other versioned types or OCaml built-in types

  to use, add coda_ppx to the dune pps list, and add to a type declaration (for
  a version of 1):

    [@@deriving version { n = 1 }

*)

open Core_kernel
open Ppxlib

let is_version_application expr =
  let version_id id =
    match id.txt with Lident s -> String.equal s "version" | _ -> false
  in
  let is_version_number num loc =
    match num with
    | Pexp_constant (Pconst_integer (n, None)) ->
        if int_of_string n <= 0 then
          Location.raise_errorf ~loc "Version must be a positive number" ;
        true
    | Pexp_constant _ ->
        Location.raise_errorf ~loc "Version option must be a number"
    | _ -> false
  in
  match expr.pexp_desc with
  | Pexp_apply
      ( {pexp_desc= Pexp_ident id; _}
      , [ ( Nolabel
          , { pexp_desc=
                Pexp_record
                  ( [({txt= Lident "n"; _}, {pexp_desc= num; pexp_loc; _})]
                  , None ); _ } ) ] ) ->
      version_id id && is_version_number num pexp_loc
  | Pexp_ident id ->
      if version_id id then
        Location.raise_errorf ~loc:expr.pexp_loc
          "\"version\" requires a number option; example: \"{n = 1}\"" ;
      false
  | _ -> false

let payload_has_version payload =
  match payload with
  | PStr structure ->
      List.exists structure ~f:(fun str ->
          match str.pstr_desc with
          | Pstr_eval (expr, _) -> (
            (* "version" can appear as an application or in a tuple *)
            match expr.pexp_desc with
            | Pexp_tuple exprs ->
                List.exists exprs ~f:(fun expr -> is_version_application expr)
            | _ -> is_version_application expr )
          | _ -> false )
  | _ -> false

let attribute_has_deriving_version ((name, payload) : attribute) =
  String.equal name.txt "deriving" && payload_has_version payload

let attributes_have_deriving_version (attrs : attribute list) =
  List.exists attrs ~f:attribute_has_deriving_version

let type_has_deriving_version type_decl =
  attributes_have_deriving_version type_decl.ptype_attributes

let get_expr_version_string expr =
  match expr.pexp_desc with
  | Pexp_apply
      ( {pexp_desc= Pexp_ident {txt= Lident "version"; _}; _}
      , [ ( Nolabel
          , { pexp_desc=
                Pexp_record
                  ( [ ( {txt= Lident "n"; _}
                      , { pexp_desc=
                            Pexp_constant
                              (Pconst_integer (number_string, None)); _ } ) ]
                  , None ); _ } ) ] ) ->
      number_string
  | _ -> failwith "Expected expression to be a version application"

let find_structure_item_version_application_opt item : expression option =
  match item.pstr_desc with
  | Pstr_eval (expr, _) -> (
    match expr.pexp_desc with
    | Pexp_tuple exprs -> List.find exprs ~f:is_version_application
    | _ -> if is_version_application expr then Some expr else None )
  | _ -> None

let find_structure_version_application_opt structure =
  List.find_map structure ~f:find_structure_item_version_application_opt

let get_payload_version_string payload =
  match payload with
  | PStr structure -> (
    match find_structure_version_application_opt structure with
    | None ->
        failwith
          "Expected structure in type attribute to contain version application"
    | Some expr -> get_expr_version_string expr )
  | _ ->
      failwith
        "Expected type attribute to contain structure with version application"

let get_attributes_version_string attributes =
  match List.find attributes ~f:attribute_has_deriving_version with
  | None ->
      failwith "Expected to find type attribute with \"deriving version\""
  | Some (_name, payload) -> get_payload_version_string payload

let get_type_decl_version_string type_decl =
  get_attributes_version_string type_decl.ptype_attributes

let generate_versioned_decls type_decl =
  let loc = type_decl.ptype_loc in
  let versioned_current =
    { pstr_desc=
        Pstr_value
          ( Nonrecursive
          , [ { pvb_pat=
                  { ppat_desc= Ppat_var {txt= "__versioned__"; loc}
                  ; ppat_loc= loc
                  ; ppat_attributes= [] }
              ; pvb_expr=
                  { pexp_desc= Pexp_construct ({txt= Lident "true"; loc}, None)
                  ; pexp_loc= loc
                  ; pexp_attributes= [] }
              ; pvb_attributes= []
              ; pvb_loc= loc } ] )
    ; pstr_loc= loc }
  in
  (* TODO: add declarations for contained types *)
  [versioned_current]

(* for "version { n = m }" in deriving list, generate
   let version = m
*)
let generate_version_value_decl type_decl =
  let loc = type_decl.ptype_loc in
  let version_string = get_type_decl_version_string type_decl in
  { pstr_desc=
      Pstr_value
        ( Nonrecursive
        , [ { pvb_pat=
                { ppat_desc= Ppat_var {txt= "version"; loc}
                ; ppat_loc= loc
                ; ppat_attributes= [] }
            ; pvb_expr=
                { pexp_desc=
                    Pexp_constant (Pconst_integer (version_string, None))
                ; pexp_loc= loc
                ; pexp_attributes= [] }
            ; pvb_attributes= []
            ; pvb_loc= loc } ] )
  ; pstr_loc= loc }

(* check that a versioned type occurs in valid module hierarchy and is named "t"
   if valid syntactically, generate value declarations
 *)
let validate_and_generate_versioned (decls : structure_item list) type_decl
    inner3_modules =
  if type_has_deriving_version type_decl then (
    if not (String.equal type_decl.ptype_name.txt "t") then
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type must be named \"t\", got: \"%s\""
        type_decl.ptype_name.txt ;
    if not (List.is_empty type_decl.ptype_params) then
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type must not have type parameters" ;
    match inner3_modules with
    | [ {txt= "T"; _}
      ; {txt= version_name; loc= version_name_loc}
      ; {txt= "Stable"; _} ] ->
        let len = String.length version_name in
        if not (Char.equal version_name.[0] 'V' && len > 1) then
          Location.raise_errorf ~loc:version_name_loc
            "Versioning module containing versioned type must be named Vn, \
             for some number n"
        else
          let numeric_part = String.sub version_name ~pos:1 ~len:(len - 1) in
          String.iter numeric_part ~f:(fun c ->
              if not (Char.is_digit c) then
                Location.raise_errorf ~loc:version_name_loc
                  "Versioning module name must be Vn, for some number n, got: \
                   \"%s\""
                  version_name ) ;
          (* invariant: 0th char is digit *)
          if Int.equal (Char.get_digit_exn numeric_part.[0]) 0 then
            Location.raise_errorf ~loc:version_name_loc
              "Versioning module name must be Vn, for a number n, but n \
               cannot begin with 0, got: \"%s\""
              version_name ;
          (* syntactic check passed; generate value declarations *)
          generate_version_value_decl type_decl
          :: generate_versioned_decls type_decl
          @ decls
    | _ ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type must be contained in module structure Stable.Vn.T, \
           for some number n" )
  else (* not versioned, no new declarations *)
    decls

(* generate:

     include struct
       original type declaration
       generated value declarations
    end
 *)
let add_version_decls_to_type str type_decl version_decls loc =
  { str with
    pstr_desc=
      Pstr_include
        { pincl_mod=
            { pmod_desc=
                Pmod_structure
                  ({pstr_desc= type_decl; pstr_loc= loc} :: version_decls)
            ; pmod_loc= loc
            ; pmod_attributes= [] }
        ; pincl_loc= loc
        ; pincl_attributes= [] } }

(* traverse AST *)
let versioned_syntactic_check =
  object (self)
    inherit [string loc list] Ast_traverse.fold_map as super

    (* acc is list of module names traversed, from innermost to outer *)
    method! structure_item ({pstr_desc; pstr_loc} as str) acc =
      match pstr_desc with
      (* for modules, current name is cons'ed to acc *)
      | Pstr_module ({pmb_name; pmb_expr; _} as module_details) -> (
        match pmb_expr.pmod_desc with
        | Pmod_structure structure ->
            let new_acc = pmb_name :: acc in
            let results =
              List.map structure ~f:(fun si -> self#structure_item si new_acc)
            in
            let new_str, _accs = List.unzip results in
            let new_module =
              { str with
                pstr_desc=
                  Pstr_module
                    { module_details with
                      pmb_expr=
                        {pmb_expr with pmod_desc= Pmod_structure new_str} } }
            in
            (new_module, acc)
        | _ -> (str, acc) )
      | Pstr_type (_rec_decl, type_decls) as type_decl ->
          (* if versioned, check syntactic placement of type, add code *)
          let inner3_modules = List.take acc 3 in
          (* list of generated declarations for versioned types *)
          let version_decls =
            List.fold type_decls ~init:[] ~f:(fun decls ty_decl ->
                validate_and_generate_versioned decls ty_decl inner3_modules )
          in
          if List.is_empty version_decls then (str, acc)
          else
            ( add_version_decls_to_type str type_decl version_decls pstr_loc
            , acc )
      | _ -> super#structure_item str acc
  end

let versioned_module structure =
  let new_structure, _acc = versioned_syntactic_check#structure structure [] in
  new_structure

let () =
  Driver.register_transformation "versioned_module" ~impl:versioned_module
