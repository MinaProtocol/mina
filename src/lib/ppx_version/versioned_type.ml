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

  where option is one of "rpc", "asserted", or "binable".

  Without options (the common case), the type must be named "t", and its definition
  occurs in the module hierarchy "Stable.Vn.T", where n is a positive integer.

  The "asserted" option asserts that the type is versioned, to allow compilation
  to proceed. The types referred to in the type are not checked for versioning
  with this option. The type must be contained in the module hierarchy "Stable.Vn.T".
  Eventually, all uses of this option should be removed.

  The "binable" option is a synonym for "asserted". It assumes that the type
  will be serialized using a "Binable.Of_..." or "Make_binable" functors, which relies
  on the serialization of some other type.

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

(* print versioned types *)
module Printing = struct
  let contains_deriving_bin_io (attrs : attributes) =
    match
      List.find attrs ~f:(fun ({txt; _}, _) -> String.equal txt "deriving")
    with
    | Some (_deriving, payload) -> (
      match payload with
      (* always have a tuple here; any deriving items are in addition to `version` *)
      | PStr [{pstr_desc= Pstr_eval ({pexp_desc= Pexp_tuple items; _}, _); _}]
        ->
          List.exists items ~f:(fun item ->
              match item with
              | {pexp_desc= Pexp_ident {txt= Lident "bin_io"; _}; _} ->
                  true
              | _ ->
                  false )
      | _ ->
          false )
    | None ->
        (* unreachable *)
        false

  (* singleton attribute *)
  let just_bin_io =
    let loc = Location.none in
    [ ( {txt= "deriving"; loc}
      , PStr
          [ { pstr_desc=
                Pstr_eval
                  ( { pexp_desc= Pexp_ident {txt= Lident "bin_io"; loc}
                    ; pexp_loc= loc
                    ; pexp_attributes= [] }
                  , [] )
            ; pstr_loc= loc } ] ) ]

  (* filter attributes from types, except for bin_io, don't care about changes to others *)
  let filter_type_decls_attrs type_decl =
    (* retain `deriving bin_io` *)
    let attrs = type_decl.ptype_attributes in
    let ptype_attributes =
      if contains_deriving_bin_io attrs then just_bin_io else []
    in
    {type_decl with ptype_attributes}

  (* convert type_decls to structure item so we can print it *)
  let type_decls_to_stri type_decls =
    (* type derivers only work with recursive types *)
    {pstr_desc= Pstr_type (Ast.Recursive, type_decls); pstr_loc= Location.none}

  (* prints module_path:type_definition *)
  let print_type ~options:_ ~path type_decls =
    let path_len = List.length path in
    List.iteri path ~f:(fun i s ->
        printf "%s" s ;
        if i < path_len - 1 then printf "." ) ;
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
  let gen_empty_sig ~options:_ ~path:_ _type_decls = []
end

(* real derivers *)
module Deriving = struct
  type generation_kind = Plain | Rpc

  let validate_rpc_type_decl inner3_modules type_decl =
    match List.take inner3_modules 2 with
    | ["T"; module_version] ->
        validate_module_version module_version type_decl.ptype_loc
    | _ ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned RPC type must be contained in module path Vn.T, for some \
           number n"

  let validate_plain_type_decl inner3_modules type_decl =
    match inner3_modules with
    | ["T"; module_version; "Stable"] | module_version :: "Stable" :: _ ->
        (* NOTE: The pattern here with "T" can be removed when the registration
         functors are replaced with the versioned module ppx.
      *)
        validate_module_version module_version type_decl.ptype_loc
    | _ ->
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type must be contained in module path Stable.Vn.T, for \
           some number n"

  (* check that a versioned type occurs in valid module hierarchy and is named "t"
     (for RPC types, the name can be "query", "response", or "msg")
  *)
  let validate_type_decl inner3_modules generation_kind type_decl =
    let name = type_decl.ptype_name.txt in
    let loc = type_decl.ptype_name.loc in
    match generation_kind with
    | Rpc ->
        let rpc_valid_names = ["query"; "response"; "msg"] in
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

  let module_name_from_plain_path inner3_modules =
    match inner3_modules with
    | ["T"; module_version; "Stable"] | module_version :: "Stable" :: _ ->
        (* NOTE: The pattern here with "T" can be removed when the registration
         functors are replaced with the versioned module ppx.
      *)
        module_version
    | _ ->
        failwith "module_name_from_plain_path: unexpected module path"

  let module_name_from_rpc_path inner3_modules =
    match List.take inner3_modules 2 with
    | ["T"; module_version] ->
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
      let _ = version]

  let ocaml_builtin_types =
    [ "bytes"
    ; "int"
    ; "int32"
    ; "int64"
    ; "float"
    ; "char"
    ; "string"
    ; "bool"
    ; "unit" ]

  let ocaml_builtin_type_constructors = ["list"; "array"; "option"; "ref"]

  let jane_street_type_constructors = ["sexp_opaque"]

  let is_version_module vn =
    let len = String.length vn in
    len > 1
    && Char.equal vn.[0] 'V'
    &&
    let numeric_part = String.sub vn ~pos:1 ~len:(len - 1) in
    String.for_all numeric_part ~f:Char.is_digit
    && not (Int.equal (Char.get_digit_exn numeric_part.[0]) 0)

  (* true iff module_path is of form M. ... .Stable.Vn, where M is Core or Core_kernel, and n is integer *)
  let is_jane_street_stable_module module_path =
    let hd_elt = List.hd_exn module_path in
    List.mem jane_street_modules hd_elt ~equal:String.equal
    &&
    match List.rev module_path with
    | vn :: "Stable" :: _ ->
        is_version_module vn
    | vn :: label :: "Stable" :: "Time" :: _
      when List.mem ["Span"; "With_utc_sexp"] label ~equal:String.equal ->
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
        Ppx_deriving.raise_errorf ~loc
          "Type name contains unexpected application"

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
    match core_type.ptyp_desc with
    | Ptyp_constr ({txt; _}, core_types) -> (
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
            || List.mem jane_street_type_constructors id ~equal:String.equal
          then
            match core_types with
            | [_] ->
                generate_version_lets_for_core_types type_name core_types
            | _ ->
                Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
                  "Type constructor \"%s\" expects one type argument, got %d"
                  id (List.length core_types)
          else
            Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
              "\"%s\" is neither an OCaml type constructor nor a versioned type"
              id
      | Ldot (prefix, "t") ->
          (* type t = A.B.t
             if prefix not trustlisted, generate: let _ = A.B.__versioned__
             disallow Stable.Latest.t
          *)
          if is_stable_latest prefix then
            Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
              "Cannot use type of the form Stable.Latest.t within a versioned \
               type" ;
          let core_type_decls =
            generate_version_lets_for_core_types type_name core_types
          in
          if trustlisted_prefix prefix ~loc:core_type.ptyp_loc then
            core_type_decls
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
                          ["Table"; "Hash_set"; "Hash_queue"]
                          label ~equal:String.equal ->
                  longident
              | _ ->
                  prefix
            in
            let versioned_ident =
              { pexp_desc=
                  Pexp_ident {txt= Ldot (new_prefix, "__versioned__"); loc}
              ; pexp_loc
              ; pexp_attributes= [] }
            in
            [%str let _ = [%e versioned_ident]] @ core_type_decls
      | _ ->
          Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
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
        Ppx_deriving.raise_errorf ~loc:core_type.ptyp_loc
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
      List.concat_map [ty1; ty2]
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
            Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
              "Versioned type, not a label or variant, must have manifest \
               (right-hand side)" )
      | Ptype_variant ctor_decls ->
          List.fold ctor_decls ~init:[] ~f:(fun accum ctor_decl ->
              generate_constructor_decl_decls type_name ctor_decl @ accum )
      | Ptype_record label_decls ->
          generate_version_lets_for_label_decls type_name label_decls
      | Ptype_open ->
          Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
            "Versioned type may not be open"
    in
    constraint_type_version_decls @ main_type_version_decls

  let generate_versioned_decls ~asserted generation_kind type_decl =
    let module E = Ppxlib.Ast_builder.Make (struct
      let loc = type_decl.ptype_loc
    end) in
    let open E in
    let versioned_current = [%stri let __versioned__ = ()] in
    if asserted then [versioned_current]
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
        { loc_start= type_decl1.ptype_loc.loc_start
        ; loc_end= type_decl2.ptype_loc.loc_end
        ; loc_ghost= true }
      in
      Ppx_deriving.raise_errorf ~loc
        "Versioned type must be just one type \"t\", not a sequence of types"
    ) ;
    type_decl1

  let check_for_option s options =
    let is_s_opt opt =
      match opt with
      | str1, {pexp_desc= Pexp_ident {txt= Lident str2; _}; _} ->
          String.equal s str1 && String.equal s str2
      | _ ->
          false
    in
    List.find options ~f:is_s_opt |> Option.is_some

  let validate_options valid options =
    let get_option_name (str, _) = str in
    let is_valid opt =
      get_option_name opt |> List.mem valid ~equal:String.equal
    in
    if not (List.for_all options ~f:is_valid) then
      let exprs = List.map options ~f:snd in
      let {pexp_loc= loc1; _} = List.hd_exn exprs in
      let {pexp_loc= loc2; _} = List.hd_exn (List.rev exprs) in
      let loc =
        {loc_start= loc1.loc_start; loc_end= loc2.loc_end; loc_ghost= true}
      in
      Ppx_deriving.raise_errorf ~loc "Valid options to \"version\" are: %s"
        (String.concat ~sep:"," valid)

  let generate_let_bindings_for_type_decl_str ~options ~path type_decls =
    ignore (validate_options ["rpc"; "asserted"; "binable"] options) ;
    let type_decl = get_type_decl_representative type_decls in
    let asserted =
      check_for_option "asserted" options || check_for_option "binable" options
    in
    let rpc = check_for_option "rpc" options in
    if asserted && rpc then
      Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
        "Options \"asserted\" and \"rpc\" cannot be combined" ;
    let generation_kind = if rpc then Rpc else Plain in
    let inner3_modules = List.take (List.rev path) 3 in
    validate_type_decl inner3_modules generation_kind type_decl ;
    let versioned_decls =
      generate_versioned_decls ~asserted generation_kind type_decl
    in
    let type_name = type_decl.ptype_name.txt in
    (* generate version number for Rpc response, but not for query, so we
       don't get an unused value
    *)
    if generation_kind = Rpc && String.equal type_name "query" then
      versioned_decls
    else
      generate_version_number_decl inner3_modules type_decl.ptype_loc
        generation_kind
      @ versioned_decls

  let generate_val_decls_for_type_decl type_decl ~numbered =
    match type_decl.ptype_kind with
    (* the structure of the type doesn't affect what we generate for signatures *)
    | Ptype_abstract | Ptype_variant _ | Ptype_record _ ->
        let loc = type_decl.ptype_loc in
        let versioned = [%sigi: val __versioned__ : unit] in
        if numbered then [[%sigi: val version : int]; versioned]
        else [versioned]
    | Ptype_open ->
        (* but the type can't be open, else it might vary over time *)
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Versioned type in a signature must not be open"

  let generate_val_decls_for_type_decl_sig ~options ~path:_ type_decls =
    (* in a signature, the module path may vary *)
    ignore (validate_options ["numbered"] options) ;
    let type_decl = get_type_decl_representative type_decls in
    let numbered = check_for_option "numbered" options in
    generate_val_decls_for_type_decl type_decl ~numbered
end

(* at preprocessing time, choose between printing, deriving derivers *)
let choose_deriver ~printing ~deriving =
  if !printing_ref then printing else deriving

let type_decl_str ~options ~path ty_decls =
  let deriver =
    choose_deriver ~printing:Printing.print_type
      ~deriving:Deriving.generate_let_bindings_for_type_decl_str
  in
  deriver ~options ~path ty_decls

let type_decl_sig ~options ~path ty_decls =
  let deriver =
    choose_deriver ~printing:Printing.gen_empty_sig
      ~deriving:Deriving.generate_val_decls_for_type_decl_sig
  in
  deriver ~options ~path ty_decls

let () =
  Ppx_deriving.(register (create deriver ~type_decl_str ~type_decl_sig ()))
