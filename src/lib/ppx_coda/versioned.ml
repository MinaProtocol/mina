(* versioned.ml -- static enforcement of versioned types via ppx

   1) check that versioned type always in Stable.Vn.T module hierarchy
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

(* {wrapped} *)
let is_wrapped_option args =
  match args with
  | [ ( Nolabel
      , { pexp_desc=
            Pexp_record
              ( [ ( {txt= Lident "wrapped"; _}
                  , {pexp_desc= Pexp_ident {txt= Lident "wrapped"; _}; _} ) ]
              , None ); _ } ) ] ->
      true
  | _ -> false

let item_versioned_info_opt item : version_info option =
  let is_version_id id =
    match id.txt with Lident s -> String.equal s "version" | _ -> false
  in
  match item with
  | Pexp_ident id ->
      if is_version_id id then Some {versioned= true; wrapped= false} else None
  | Pexp_apply ({pexp_desc= Pexp_ident id; _}, args) ->
      if is_version_id id then
        if is_wrapped_option args then Some {versioned= true; wrapped= true}
        else
          (* build location from entire args list *)
          let _, {pexp_loc= loc1; _} = List.hd_exn args in
          let _, {pexp_loc= loc2; _} = List.hd_exn (List.rev args) in
          let loc =
            {loc_start= loc1.loc_start; loc_end= loc2.loc_end; loc_ghost= true}
          in
          Location.raise_errorf ~loc
            "Invalid option(s) to \"version\", can only be \"wrapped\""
      else None
  | _ -> None

let payload_version_info_opt payload : version_info option =
  match payload with
  | PStr structure ->
      List.find_map structure ~f:(fun str ->
          match str.pstr_desc with
          | Pstr_eval (expr, _) -> (
            (* "version" can appear as:
                - an indvidual identifier
                - an application, or
                - in a tuple, as an identifier or application
            *)
            match expr.pexp_desc with
            | Pexp_ident _ | Pexp_apply _ ->
                item_versioned_info_opt expr.pexp_desc
            | Pexp_tuple exprs ->
                List.find_map exprs ~f:(fun expr ->
                    item_versioned_info_opt expr.pexp_desc )
            | _ -> None )
          | _ -> None )
  | _ -> None

let attribute_version_info_opt ((name, payload) : attribute) :
    version_info option =
  if String.equal name.txt "deriving" then payload_version_info_opt payload
  else None

let get_attributes_version_info_opt (attrs : attribute list) :
    version_info option =
  List.find_map attrs ~f:attribute_version_info_opt

let get_type_version_info_opt type_decl : version_info option =
  get_attributes_version_info_opt type_decl.ptype_attributes

let validate_module_version module_version =
  let version_name = module_version.txt in
  let version_name_loc = module_version.loc in
  let len = String.length version_name in
  if not (Char.equal version_name.[0] 'V' && len > 1) then
    Location.raise_errorf ~loc:version_name_loc
      "Versioning module containing versioned type must be named Vn, for some \
       number n"
  else
    let numeric_part = String.sub version_name ~pos:1 ~len:(len - 1) in
    String.iter numeric_part ~f:(fun c ->
        if not (Char.is_digit c) then
          Location.raise_errorf ~loc:version_name_loc
            "Versioning module name must be Vn, for some number n, got: \"%s\""
            version_name ) ;
    (* invariant: 0th char is digit *)
    if Int.equal (Char.get_digit_exn numeric_part.[0]) 0 then
      Location.raise_errorf ~loc:version_name_loc
        "Versioning module name must be Vn, for a number n, but n cannot \
         begin with 0, got: \"%s\""
        version_name

let validate_unwrapped_type_decl inner3_modules type_decl =
  match inner3_modules with
  | [{txt= "T"; _}; module_version; {txt= "Stable"; _}] ->
      validate_module_version module_version
  | _ ->
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Versioned type must be contained in module structure Stable.Vn.T, \
         for some number n"

let validate_wrapped_type_decl inner3_modules type_decl =
  match inner3_modules with
  | [module_version; {txt= "Stable"; _}; {txt= "Wrapped"; _}] ->
      validate_module_version module_version
  | _ ->
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Wrapped versioned type must be contained in module structure \
         Wrapped.Stable.Vn, for some number n"

(* check that a versioned type occurs in valid module hierarchy and is named "t"
 *)
let validate_type_decl inner3_modules type_decl =
  match get_type_version_info_opt type_decl with
  | None
  (* should not happen *)
   |Some {versioned= false; _} ->
      ()
  | Some {versioned= true; wrapped} ->
      if not (String.equal type_decl.ptype_name.txt "t") then
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type must be named \"t\", got: \"%s\""
          type_decl.ptype_name.txt ;
      if not (List.is_empty type_decl.ptype_params) then
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type must not have type parameters" ;
      if wrapped then validate_wrapped_type_decl inner3_modules type_decl
      else validate_unwrapped_type_decl inner3_modules type_decl

(* syntax check only *)
let versioned_syntactic_check =
  object (self)
    inherit [string loc list] Ast_traverse.fold as super

    (* module_path is list of module names traversed, from innermost to outer *)
    method! structure_item ({pstr_desc; _} as str) module_path =
      match pstr_desc with
      (* for modules, current name is cons'ed to acc *)
      | Pstr_module {pmb_name; pmb_expr; _} -> (
        match pmb_expr.pmod_desc with
        | Pmod_structure structure ->
            let new_module_path = pmb_name :: module_path in
            List.iter structure ~f:(fun si ->
                ignore (self#structure_item si new_module_path) ) ;
            (* we've left the structure, so we're in the same module hierarchy we started with *)
            module_path
        | _ -> module_path )
      | Pstr_type (_rec_decl, type_decls) ->
          (* if versioned, check syntactic placement of type, add code *)
          let inner3_modules = List.take module_path 3 in
          List.iter type_decls ~f:(validate_type_decl inner3_modules) ;
          module_path
      | _ -> super#structure_item str module_path
  end

let check_versioned_module structure =
  ignore (versioned_syntactic_check#structure structure []) ;
  structure

let () =
  Driver.register_transformation "versioned_module"
    ~impl:check_versioned_module
