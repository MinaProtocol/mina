(* versioned_types.ml -- static enforcement of versioned types via ppx *)

(* If the dune profile defines "print_versioned_types" to be true, this deriver
    prints a representation of each versioned type to stdout. The driver "print_versioned_types"
    can be used to print the types from a particular OCaml source file. This facility is
    meant to be used in CI to detect changes to versioned types.

    Otherwise, we use this deriver as follows:

    1) check that versioned type always in valid module hierarchy
    2) versioned types depend only on other versioned types or OCaml built-in types

   to use, add coda_ppx to the dune pps list, and annotate a type declaration with
   either

     [@@deriving version]

   or

     [@@deriving version { option }]

   where option is one of "rpc" or "binable".

   Without options (the common case), the type must be named "t", and its definition
   occurs in the module hierarchy "Stable.Vn" or "Stable.Vn.T", where n is a positive integer.

   The "binable" option asserts that the type is versioned, to allow compilation
   to proceed. The types referred to in the type are not checked for versioning
   with this option. It assumes that the type will be serialized using a
   "Binable.Of_..." or "Make_binable" functors, which relies on the serialization of
   some other type.

   If "rpc" is true, again, the type must be named "query", "response", or "msg",
   and the type definition occurs in the hierarchy "Vn.T".

   All these options are available for types within structures.

   Within signatures, the declaration

     val __versioned__ : unit

   is generated. If the "numbered" option is given, then

     val version : int

   is also generated. This option should be needed only by the internal versioning
   machinery, and not in ordinary code. No other options are available within signatures.
*)

open Core_kernel
open Ppxlib
open Versioned_util

let deriver = "version"

let printing_ref = ref false

let set_printing () = printing_ref := true

let unset_printing () = printing_ref := false

(* path is filename.ml.M1.M2.... *)
let module_path_list path = List.drop (String.split path ~on:'.') 2

(* print versioned types *)
module Printing = struct
  let contains_deriving_bin_io (attrs : attributes) =
    let derivers =
      Ast_pattern.(
        attribute ~name:(string "deriving") ~payload:(single_expr_payload __))
    in
    match
      List.find_map attrs ~f:(fun attr ->
          parse_opt derivers Location.none attr (fun l -> Some l) )
    with
    | Some derivers ->
        let derivers =
          match derivers.pexp_desc with
          | Pexp_tuple derivers ->
              derivers
          | _ ->
              [ derivers ]
        in
        let bin_io_pattern =
          Ast_pattern.(pexp_ident (lident (string "bin_io")))
        in
        List.exists derivers ~f:(fun deriver ->
            Option.is_some
            @@ parse_opt bin_io_pattern Location.none deriver (Some ()) )
    | None ->
        false

  (* singleton attribute *)
  let just_bin_io =
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = Location.none
    end) in
    let open E in
    { attr_name = { txt = "deriving"; loc }
    ; attr_payload = PStr [%str bin_io]
    ; attr_loc = Location.none
    }

  (* remove internal attributes, on core type in manifest and in records or variants in kind *)
  let type_decl_remove_internal_attributes type_decl =
    let removed_in_kind =
      match type_decl.ptype_kind with
      | Ptype_variant ctors ->
          Ptype_variant
            (List.map ctors ~f:(fun ctor -> { ctor with pcd_attributes = [] }))
      | Ptype_record labels ->
          Ptype_record
            (List.map labels ~f:(fun label ->
                 { label with pld_attributes = [] } ) )
      | kind ->
          kind
    in
    let removed_in_manifest =
      Option.map type_decl.ptype_manifest ~f:(fun core_type ->
          { core_type with ptyp_attributes = [] } )
    in
    { type_decl with
      ptype_manifest = removed_in_manifest
    ; ptype_kind = removed_in_kind
    }

  (* filter attributes from types, except for bin_io, don't care about changes to others *)
  let filter_type_decls_attrs type_decl =
    (* retain only `deriving bin_io` in deriving list *)
    let ptype_attributes =
      if contains_deriving_bin_io type_decl.ptype_attributes then
        [ just_bin_io ]
      else []
    in
    let type_decl_no_attrs = type_decl_remove_internal_attributes type_decl in
    { type_decl_no_attrs with ptype_attributes }

  (* convert type_decls to structure item so we can print it *)
  let type_decls_to_stri type_decls =
    (* type derivers only work with recursive types *)
    { pstr_desc = Pstr_type (Ast.Recursive, type_decls)
    ; pstr_loc = Location.none
    }

  (* prints path_to_type:type_definition *)
  let print_type ~loc:_ ~path (_rec_flag, type_decls) _rpc _binable =
    let module_path = module_path_list path in
    let path_len = List.length module_path in
    List.iteri module_path ~f:(fun i s ->
        printf "%s" s ;
        if i < path_len - 1 then printf "." ) ;
    printf ".%s" (List.hd_exn type_decls).ptype_name.txt ;
    printf ":%!" ;
    let type_decls_filtered_attrs =
      List.map type_decls ~f:filter_type_decls_attrs
    in
    let stri = type_decls_to_stri type_decls_filtered_attrs in
    Pprintast.structure_item Versioned_util.diff_formatter stri ;
    Format.pp_print_flush Versioned_util.diff_formatter () ;
    printf "\n%!" ;
    []

  (* we're worried about changes to the serialization of types, which can occur via changes to implementations,
     so nothing to do for signatures
  *)
  let gen_empty_sig ~loc:_ ~path:_ (_rec_flag, _type_decls) = []
end

(* real derivers *)
module Deriving = struct
  type generation_kind = Plain | Rpc

  let validate_rpc_type_decl inner3_modules type_decl =
    match List.take inner3_modules 2 with
    | [ "T"; module_version ] ->
        validate_module_version module_version type_decl.ptype_loc
    | _ ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned RPC type must be contained in module path Vn.T, for some \
           number n"

  let validate_plain_type_decl inner3_modules type_decl =
    match inner3_modules with
    | [ "T"; module_version; "Stable" ] | module_version :: "Stable" :: _ ->
        validate_module_version module_version type_decl.ptype_loc
    | _ ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type must be contained in module path Stable.Vn or \
           Stable.Vn.T, for some number n"

  (* check that a versioned type occurs in valid module hierarchy and is named "t"
     (for RPC types, the name can be "query", "response", or "msg")
  *)
  let validate_type_decl inner3_modules generation_kind type_decl =
    let name = type_decl.ptype_name.txt in
    let loc = type_decl.ptype_name.loc in
    match generation_kind with
    | Rpc ->
        let rpc_valid_names = [ "query"; "response"; "msg" ] in
        if
          List.find rpc_valid_names ~f:(fun ty -> String.equal ty name)
          |> Option.is_none
        then
          Location.raise_errorf ~loc
            "RPC versioned type must be named one of \"%s\", got: \"%s\""
            (String.concat ~sep:"," rpc_valid_names)
            name ;
        validate_rpc_type_decl inner3_modules type_decl
    | Plain ->
        let valid_name = "t" in
        if not (String.equal name valid_name) then
          Location.raise_errorf ~loc
            "Versioned type must be named \"%s\", got: \"%s\"" valid_name name ;
        validate_plain_type_decl inner3_modules type_decl

  (* module structure in this case validated by linter *)

  let module_name_from_plain_path inner3_modules =
    match inner3_modules with
    | [ "T"; module_version; "Stable" ] | module_version :: "Stable" :: _ ->
        module_version
    | _ ->
        failwith "module_name_from_plain_path: unexpected module path"

  let module_name_from_rpc_path inner3_modules =
    match List.take inner3_modules 2 with
    | [ "T"; module_version ] ->
        module_version
    | _ ->
        failwith "module_name_from_rpc_path: unexpected module path"

  (* generate "let version = n", when version module is Vn *)
  let generate_version_number_decl inner3_modules loc generation_kind =
    (* invariant: we've checked module name already *)
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = loc
    end) in
    let open E in
    let module_name =
      match generation_kind with
      | Plain ->
          module_name_from_plain_path inner3_modules
      | Rpc ->
          module_name_from_rpc_path inner3_modules
    in
    let version = version_of_versioned_module_name module_name in
    [%str
      let version = [%e eint version]

      (* to prevent unused value warnings *)
      let (_ : _) = version]

  let ocaml_builtin_types =
    [ "bytes"
    ; "int"
    ; "int32"
    ; "int64"
    ; "float"
    ; "char"
    ; "string"
    ; "bool"
    ; "unit"
    ]

  let ocaml_builtin_type_constructors = [ "list"; "array"; "option"; "ref" ]

  (* true iff module_path is of form M. ... .Stable.Vn, where M is Core or Core_kernel, and n is integer *)
  let is_jane_street_stable_module module_path =
    let hd_elt = List.hd_exn module_path in
    List.mem jane_street_modules hd_elt ~equal:String.equal
    &&
    match List.rev module_path with
    | vn :: "Stable" :: _ ->
        Versioned_util.is_version_module vn
    | vn :: label :: "Stable" :: "Time" :: _
      when List.mem [ "Span"; "With_utc_sexp" ] label ~equal:String.equal ->
        (* special cases, maybe improper module structure *)
        is_version_module vn
    | _ ->
        false

  let trustlisted_prefix prefix ~loc =
    match prefix with
    | Lident id ->
        String.equal id "Bitstring"
    | Ldot _ ->
        let module_path = Longident.flatten_exn prefix in
        is_jane_street_stable_module module_path
    | Lapply _ ->
        Location.raise_errorf ~loc "Type name contains unexpected application"

  (* disallow Stable.Latest types in versioned types *)

  let is_stable_latest =
    let is_longident_with_id id = function
      | Lident s when String.equal id s ->
          true
      | Ldot (_lident, s) when String.equal id s ->
          true
      | _ ->
          false
    in
    let is_stable = is_longident_with_id "Stable" in
    let is_latest = is_longident_with_id "Latest" in
    fun prefix ->
      is_latest prefix
      &&
      match prefix with
      | Ldot (lident, _) when is_stable lident ->
          true
      | _ ->
          false

  let rec generate_core_type_version_decls type_name core_type =
    let version_asserted_str = "version_asserted" in
    match core_type.ptyp_desc with
    | Ptyp_constr ({ txt; _ }, core_types) -> (
        match txt with
        | Lident id ->
            (* type t = id *)
            if String.equal id type_name (* recursion *) then []
            else if
              List.is_empty core_types
              && List.mem ocaml_builtin_types id ~equal:String.equal
            then (* no versioning to worry about *)
              []
            else if
              List.mem ocaml_builtin_type_constructors id ~equal:String.equal
            then
              match core_types with
              | [ _ ] ->
                  generate_version_lets_for_core_types type_name core_types
              | _ ->
                  Location.raise_errorf ~loc:core_type.ptyp_loc
                    "Type constructor \"%s\" expects one type argument, got %d"
                    id (List.length core_types)
            else
              Location.raise_errorf ~loc:core_type.ptyp_loc
                "\"%s\" is neither an OCaml type constructor nor a versioned \
                 type"
                id
        | Ldot (prefix, "t") ->
            (* type t = A.B.t
               if prefix not trustlisted, generate: let _ = A.B.__versioned__
               disallow Stable.Latest.t
            *)
            if is_stable_latest prefix then
              Location.raise_errorf ~loc:core_type.ptyp_loc
                "Cannot use type of the form Stable.Latest.t within a \
                 versioned type" ;
            let core_type_decls =
              generate_version_lets_for_core_types type_name core_types
            in
            (* type t = M.t [@version_asserted] *)
            let version_asserted =
              List.find core_type.ptyp_attributes ~f:(fun attr ->
                  String.equal attr.attr_name.txt version_asserted_str )
              |> Option.is_some
            in
            if
              version_asserted
              || trustlisted_prefix prefix ~loc:core_type.ptyp_loc
            then core_type_decls
            else
              let loc = core_type.ptyp_loc in
              let pexp_loc = loc in
              let new_prefix =
                (* allow types within stable-versioned modules generated
                   by Hashable.Make_binable, like M.Stable.Vn.Table.t;
                   generate "let _ = M.Stable.Vn.__versioned__"
                *)
                match prefix with
                | Ldot ((Ldot (_, vn) as longident), label)
                  when is_version_module vn
                       && List.mem
                            [ "Table"; "Hash_set"; "Hash_queue" ]
                            label ~equal:String.equal ->
                    longident
                | _ ->
                    prefix
              in
              let versioned_ident =
                { pexp_desc =
                    Pexp_ident { txt = Ldot (new_prefix, "__versioned__"); loc }
                ; pexp_loc
                ; pexp_loc_stack = []
                ; pexp_attributes = []
                }
              in
              [%str let (_ : _) = [%e versioned_ident]] @ core_type_decls
        | _ ->
            Location.raise_errorf ~loc:core_type.ptyp_loc
              "Unrecognized type constructor for versioned type" )
    | Ptyp_tuple core_types ->
        (* type t = t1 * t2 * t3 *)
        generate_version_lets_for_core_types type_name core_types
    | Ptyp_variant _ ->
        (* type t = [ `A | `B ] *)
        []
    | Ptyp_var _ ->
        (* type variable *)
        []
    | Ptyp_any ->
        (* underscore *)
        []
    | _ ->
        Location.raise_errorf ~loc:core_type.ptyp_loc
          "Can't determine versioning for contained type"

  and generate_version_lets_for_core_types type_name core_types =
    List.fold_right core_types ~init:[] ~f:(fun core_type accum ->
        generate_core_type_version_decls type_name core_type @ accum )

  let generate_version_lets_for_label_decls type_name label_decls =
    generate_version_lets_for_core_types type_name
      (List.map label_decls ~f:(fun lab_decl -> lab_decl.pld_type))

  let generate_constructor_decl_decls type_name ctor_decl =
    let result_lets =
      match ctor_decl.pcd_res with
      | None ->
          []
      | Some res ->
          (* for GADTs, check versioned-ness of parameters to result type *)
          let ty_params =
            match res.ptyp_desc with
            | Ptyp_constr (_, params) ->
                params
            | _ ->
                failwith
                  "generate_constructor_decl_decls: expected type parameter \
                   list"
          in
          generate_version_lets_for_core_types type_name ty_params
    in
    match ctor_decl.pcd_args with
    | Pcstr_tuple core_types ->
        (* C of T1 * ... * Tn, or GADT C : T1 -> T2 *)
        let arg_lets =
          generate_version_lets_for_core_types type_name core_types
        in
        arg_lets @ result_lets
    | Pcstr_record label_decls ->
        (* C of { ... }, or GADT C : { ... } -> T *)
        let arg_lets =
          generate_version_lets_for_label_decls type_name label_decls
        in
        arg_lets @ result_lets

  let generate_constraint_type_decls type_name cstrs =
    let gen_for_constraint (ty1, ty2, _loc) =
      List.concat_map [ ty1; ty2 ]
        ~f:(generate_core_type_version_decls type_name)
    in
    List.concat_map cstrs ~f:gen_for_constraint

  let generate_contained_type_version_decls type_decl =
    let type_name = type_decl.ptype_name.txt in
    let constraint_type_version_decls =
      generate_constraint_type_decls type_decl.ptype_name.txt
        type_decl.ptype_cstrs
    in
    let main_type_version_decls =
      match type_decl.ptype_kind with
      | Ptype_abstract -> (
          match type_decl.ptype_manifest with
          | Some manifest ->
              generate_core_type_version_decls type_name manifest
          | None ->
              Location.raise_errorf ~loc:type_decl.ptype_loc
                "Versioned type, not a label or variant, must have manifest \
                 (right-hand side)" )
      | Ptype_variant ctor_decls ->
          List.fold ctor_decls ~init:[] ~f:(fun accum ctor_decl ->
              generate_constructor_decl_decls type_name ctor_decl @ accum )
      | Ptype_record label_decls ->
          generate_version_lets_for_label_decls type_name label_decls
      | Ptype_open ->
          Location.raise_errorf ~loc:type_decl.ptype_loc
            "Versioned type may not be open"
    in
    constraint_type_version_decls @ main_type_version_decls

  let generate_versioned_decls ~binable generation_kind type_decl =
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = type_decl.ptype_loc
    end) in
    let open E in
    let versioned_current = [%stri let __versioned__ = ()] in
    if binable then [ versioned_current ]
    else
      match generation_kind with
      | Rpc ->
          (* check whether contained types are versioned,
             but don't assert versioned-ness of this type *)
          generate_contained_type_version_decls type_decl
      | Plain ->
          (* check contained types, assert this type is versioned *)
          versioned_current :: generate_contained_type_version_decls type_decl

  let get_type_decl_representative type_decls =
    let type_decl1 = List.hd_exn type_decls in
    let type_decl2 = List.hd_exn (List.rev type_decls) in
    ( if not (Int.equal (List.length type_decls) 1) then
      let loc =
        { loc_start = type_decl1.ptype_loc.loc_start
        ; loc_end = type_decl2.ptype_loc.loc_end
        ; loc_ghost = true
        }
      in
      Location.raise_errorf ~loc
        "Versioned type must be just one type \"t\", not a sequence of types" ) ;
    type_decl1

  let generate_let_bindings_for_type_decl_str ~loc ~path (_rec_flag, type_decls)
      rpc binable =
    let type_decl = get_type_decl_representative type_decls in
    if binable && rpc then
      Location.raise_errorf ~loc:type_decl.ptype_loc
        "Options \"binable\" and \"rpc\" cannot be combined" ;
    let generation_kind = if rpc then Rpc else Plain in
    let module_path = module_path_list path in
    let inner3_modules = List.take (List.rev module_path) 3 in
    (* TODO: when Module_version.Registration goes away, remove
       the empty list special case
    *)
    if List.is_empty inner3_modules then
      (* module path doesn't seem to be tracked inside test module *)
      []
    else (
      validate_type_decl inner3_modules generation_kind type_decl ;
      let versioned_decls =
        generate_versioned_decls ~binable generation_kind type_decl
      in
      let type_name = type_decl.ptype_name.txt in
      (* generate version number for Rpc response, but not for query, so we
         don't get an unused value
      *)
      match generation_kind with
      | Rpc when String.equal type_name "query" ->
          versioned_decls
      | _ ->
          generate_version_number_decl inner3_modules loc generation_kind
          @ versioned_decls )

  let generate_val_decls_for_type_decl ~loc type_decl =
    match type_decl.ptype_kind with
    (* the structure of the type doesn't affect what we generate for signatures *)
    | Ptype_abstract | Ptype_variant _ | Ptype_record _ ->
        [ [%sigi: val __versioned__ : unit] ]
    | Ptype_open ->
        (* but the type can't be open, else it might vary over time *)
        Location.raise_errorf ~loc
          "Versioned type in a signature must not be open"

  let generate_val_decls_for_type_decl_sig ~loc ~path:_ (_rec_flag, type_decls)
      =
    (* in a signature, the module path may vary *)
    let type_decl = get_type_decl_representative type_decls in
    generate_val_decls_for_type_decl ~loc type_decl
end

(* at preprocessing time, choose between printing, deriving derivers *)
let choose_deriver ~printing ~deriving =
  if !printing_ref then printing else deriving

let str_type_decl :
    (structure, rec_flag * type_declaration list) Ppxlib.Deriving.Generator.t =
  let args =
    let open Ppxlib.Deriving.Args in
    empty +> flag "rpc" +> flag "binable"
  in
  let deriver ~loc ~path (rec_flag, type_decls) rpc binable =
    (choose_deriver ~printing:Printing.print_type
       ~deriving:Deriving.generate_let_bindings_for_type_decl_str )
      ~loc ~path (rec_flag, type_decls) rpc binable
  in
  Ppxlib.Deriving.Generator.make args deriver

let sig_type_decl :
    (signature, rec_flag * type_declaration list) Ppxlib.Deriving.Generator.t =
  let deriver ~loc ~path (rec_flag, type_decls) =
    (choose_deriver ~printing:Printing.gen_empty_sig
       ~deriving:Deriving.generate_val_decls_for_type_decl_sig )
      ~loc ~path (rec_flag, type_decls)
  in
  Ppxlib.Deriving.Generator.make_noarg deriver

let () =
  Ppxlib.Deriving.add deriver ~str_type_decl ~sig_type_decl
  |> Ppxlib.Deriving.ignore
