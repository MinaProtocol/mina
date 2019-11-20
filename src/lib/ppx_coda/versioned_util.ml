(* version_util.ml -- utility functions for versioning *)

open Core_kernel
open Ppxlib

let mk_loc ~loc txt = {Location.loc; txt}

let map_loc ~f {Location.loc; txt} = {Location.loc; txt= f txt}

let check_modname ~loc name =
  if name = "Stable" then name
  else
    Location.raise_errorf ~loc
      "Expected a module named Stable, but got a module named %s." name

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
