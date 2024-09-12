(* version_util.ml -- utility functions for versioning *)

open Core_kernel
open Ppxlib

let parse_opt = Ast_pattern.parse ~on_error:(fun () -> None)

let mk_loc ~loc txt = { Location.loc; txt }

let map_loc ~f { Location.loc; txt } = { Location.loc; txt = f txt }

let some_loc (x : 'a loc) = map_loc ~f:Option.some x

let check_modname ~loc name : string =
  if String.equal name "Stable" then name
  else
    Location.raise_errorf ~loc
      "Expected a module named Stable, but got a module named %s." name

(* for diffing types and binable functors, replace newlines in formatter
   with a space, so string is all on one line *)
let diff_formatter formatter =
  let out_funs = Format.(pp_get_formatter_out_functions formatter ()) in
  let out_funs' =
    { out_funs with
      out_newline = (fun () -> out_funs.out_spaces 1)
    ; out_indent = (fun _ -> ())
    }
  in
  Format.formatter_of_out_functions out_funs'

let is_version_module name =
  let len = String.length name in
  len > 1
  && Char.equal name.[0] 'V'
  &&
  let rest = String.sub name ~pos:1 ~len:(len - 1) in
  (not @@ Char.equal rest.[0] '0') && String.for_all rest ~f:Char.is_digit

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
            "Versioning module name must be Vn, for some positive number n, \
             got: \"%s\""
            module_version ) ;
    (* invariant: 0th char is digit *)
    if Int.equal (Char.get_digit_exn numeric_part.[0]) 0 then
      Location.raise_errorf ~loc
        "Versioning module name must be Vn, for a positive number n, which \
         cannot begin with 0, got: \"%s\""
        module_version

let version_of_versioned_module_name name =
  String.sub name ~pos:1 ~len:(String.length name - 1) |> int_of_string

(* modules in core and core_kernel library which are not in Core, Core_kernel modules

   see

         https://ocaml.janestreet.com/ocaml-core/latest/doc/core/index.html
         https://ocaml.janestreet.com/ocaml-core/latest/doc/core_kernel/index.html

       add to this list as needed; but more items slows things down
*)
let jane_street_library_modules = [ "Uuid" ]

let jane_street_modules =
  [ "Core"; "Core_kernel" ] @ jane_street_library_modules

let types_in_declaration_fold : string list Ast_traverse.fold =
  let rec structure s acc =
    List.fold_right ~f:(fun i acc' -> structure_item_desc i.pstr_desc acc') ~init:acc s
  and structure_item item acc = structure_item_desc item.pstr_desc acc
  and structure_item_desc desc acc =
    match desc with
    | Pstr_type (_, decls) ->
        List.fold_right
          ~f:type_declaration
          ~init:acc decls
    | Pstr_module binding ->
        module_expr_desc binding.pmb_expr.pmod_desc acc
    | Pstr_open open_description ->
        module_expr_desc open_description.popen_expr.pmod_desc acc
    | Pstr_include include_description ->
        module_expr_desc include_description.pincl_mod.pmod_desc acc
    | _ ->
        acc
  and type_declaration decl acc =
    match decl.ptype_kind with
    | Ptype_abstract ->
        Option.value_map
          ~f:(fun t -> core_type t acc)
          ~default:acc decl.ptype_manifest
    | Ptype_variant variants ->
        List.fold_right
          ~f:constructor_declaration
          ~init:acc variants
    | Ptype_record labels ->
        List.fold_right
          ~f:label_declaration
          ~init:acc labels
    | Ptype_open ->
        acc
  and constructor_declaration decl acc =
    match decl.pcd_args with
    | Pcstr_tuple types ->
        List.fold_right ~f:core_type ~init:acc types
    | Pcstr_record labels ->
        List.fold_right
          ~f:label_declaration
          ~init:acc labels
  and label_declaration decl acc = core_type decl.pld_type acc
  and lident l acc =
    match l with
    | Lident s ->
        s :: acc
    | Ldot (m, s) ->
        lident m (s :: acc)
    | _ ->
        failwith "failed to match Lident"
  and core_type (ct : core_type) acc =
    core_type_desc ct.ptyp_desc acc
  and core_type_desc ct acc =
    match ct with
    | Ptyp_var _ ->
        acc
    | Ptyp_arrow (_, source, target) ->
        core_type source (core_type target acc)
    | Ptyp_tuple types ->
        List.fold_right ~f:core_type ~init:acc types
    | Ptyp_constr (l, types) ->
        let acc' = lident l.txt acc in
        List.fold_right ~f:core_type ~init:acc' types
    | Ptyp_alias (t, _) ->
        core_type t acc
    | Ptyp_object (fields, _) ->
        List.fold_right ~f:object_field ~init:acc fields
    | Ptyp_class (_, core_types) ->
        List.fold_right ~f:core_type ~init:acc core_types
    | _ ->
        failwith "unhandled core_type_desc"
  and object_field field acc = object_field_desc field.pof_desc acc
  and object_field_desc desc acc =
    match desc with
    | Otag (_, t) ->
        core_type t acc
    | Oinherit t ->
        core_type t acc
  and module_expr_desc desc acc =
    match desc with
    | Pmod_ident l ->
        lident l.txt acc
    | Pmod_structure s ->
        structure s acc
    | Pmod_apply (e1, e2) ->
        module_expr_desc e1.pmod_desc (module_expr_desc e2.pmod_desc acc)
    | _ ->
        acc
  in

  object
    inherit [string list] Ast_traverse.fold

    method! structure = structure

    method! structure_item = structure_item

    method! structure_item_desc = structure_item_desc

    method! type_declaration = type_declaration

    method! constructor_declaration = constructor_declaration

    method! label_declaration = label_declaration

    method! core_type = core_type

    method! core_type_desc = core_type_desc

    method! object_field = object_field

    method! object_field_desc = object_field_desc

    method! module_expr_desc = module_expr_desc
  end

let collect_type_names = types_in_declaration_fold#type_declaration
