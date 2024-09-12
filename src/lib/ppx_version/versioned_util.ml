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

let rec type_appears_in_lident (needle : string) (haystack : Longident.t) : bool =
  match haystack with
  | Lident s -> String.equal s needle
  | Ldot (l, s2) -> type_appears_in_lident needle l || String.equal s2 needle
  | Lapply (l1, l2) ->
      type_appears_in_lident needle l1 || type_appears_in_lident needle l2

let rec type_appears_in_ptyp (needle : string) (haystack : core_type_desc) : bool = 
  match haystack with
    | Ptyp_arrow 
        ( _
        , {ptyp_desc = source; _}
        , {ptyp_desc = target; _}
        ) -> type_appears_in_ptyp needle source || type_appears_in_ptyp needle target
    | Ptyp_tuple types -> 
        List.exists types 
          ~f:(fun {ptyp_desc = haystacks;_} -> type_appears_in_ptyp needle haystacks)
    | Ptyp_constr ({txt = c; _}, haystacks) ->
        type_appears_in_lident needle c || List.exists ~f:(fun {ptyp_desc = h; _} -> type_appears_in_ptyp needle h) haystacks
    | Ptyp_alias _ -> failwith "Ptyp_alias not supported"
    | Ptyp_any | Ptyp_var _ | Ptyp_variant _ | Ptyp_poly _ | Ptyp_package _ | Ptyp_extension _ -> false 
    | Ptyp_object _ | Ptyp_class _ -> failwith "Ptyp_object and Ptyp_class not supported"

let type_appears_in_core_type (needle : string) ({ptyp_desc = haystack;_} : core_type) : bool =
  type_appears_in_ptyp needle haystack
  