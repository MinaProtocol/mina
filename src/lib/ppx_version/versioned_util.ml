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

module StringSet = Set.Make (String)

let types_in_declaration_fold : StringSet.t Ast_traverse.fold =
  let rec lident l acc =
    match l with
    | Lident s ->
        StringSet.add acc s
    | Ldot (m, s) ->
        lident m (StringSet.add acc s)
    | _ ->
        failwith "failed to match Lident"
  in

  object (self)
    inherit [StringSet.t] Ast_traverse.fold

    method! core_type (ct : core_type) acc =
      self#core_type_desc ct.ptyp_desc acc

    method! core_type_desc ct acc =
      match ct with
      | Ptyp_var _ ->
          acc
      | Ptyp_arrow (_, source, target) ->
          self#core_type source (self#core_type target acc)
      | Ptyp_tuple types ->
          List.fold_right ~f:self#core_type ~init:acc types
      | Ptyp_constr (l, types) ->
          let acc' = lident l.txt acc in
          List.fold_right ~f:self#core_type ~init:acc' types
      | Ptyp_alias (t, _) ->
          self#core_type t acc
      | Ptyp_class (_, core_types) ->
          List.fold_right ~f:self#core_type ~init:acc core_types
      | _ ->
          failwith "unhandled core_type_desc"

    method! module_expr_desc desc acc =
      match desc with
      | Pmod_ident l ->
          lident l.txt acc
      | Pmod_apply (e1, e2) ->
          self#module_expr_desc e1.pmod_desc
            (self#module_expr_desc e2.pmod_desc acc)
      | Pmod_structure s ->
          List.fold_right ~f:self#structure_item ~init:acc s
      | _ ->
          acc

    method! module_substitution ms acc = lident ms.pms_manifest.txt acc
  end

let modules_used_in_type_defs (module_ : module_expr) : StringSet.t =
  types_in_declaration_fold#module_expr module_ StringSet.empty
