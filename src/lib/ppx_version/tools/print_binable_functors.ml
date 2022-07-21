(* print_binable_functors.ml *)

(* print out applications of functors Binable.Of... or Bin_prot.Utils.Make_binable

   within a versioned type, these should not change
   and they should always appear within a versioned type
*)

open Core_kernel
open Ppxlib
open Ppx_version
open Versioned_util

let name = "print_binable_functors"

type accumulator = { module_path : string list }

let is_included_binable_functor_app (inc_decl : include_declaration) =
  let of_binable_pattern =
    Ast_pattern.(
      pmod_apply
        (pmod_apply (pmod_ident (ldot (lident (string "Binable")) __)) __)
        __)
  in
  let of_binable =
    match
      parse_opt of_binable_pattern Location.none inc_decl.pincl_mod
        (fun ftor _ _ -> Some ftor)
    with
    | Some ftor ->
        List.mem
          [ "Of_binable"
          ; "Of_binable_without_uuid"
          ; "Of_binable1"
          ; "Of_binable1_without_uuid"
          ; "Of_binable2"
          ; "Of_binable2_without_uuid"
          ; "Of_binable3"
          ; "Of_binable3_without_uuid"
          ; "Of_sexpable"
          ; "Of_sexpable_without_uuid"
          ; "Of_stringable"
          ; "Of_stringable_without_uuid"
          ]
          ftor ~equal:String.equal
    | _ ->
        false
  in
  let make_binable_pattern =
    Ast_pattern.(
      pmod_apply
        (pmod_ident
           (ldot
              (ldot (lident (string "Bin_prot")) (string "Utils"))
              (string "Make_binable") ) )
        __)
  in
  let make_binable =
    Option.is_some
      (parse_opt make_binable_pattern Location.none inc_decl.pincl_mod (fun _ ->
           Some () ) )
  in
  of_binable || make_binable

let print_included_binable_functor_app ~path inc =
  let path_len = List.length path in
  List.iteri path ~f:(fun i s ->
      printf "%s" s ;
      if i < path_len - 1 then printf "." ) ;
  printf ":%!" ;
  Pprintast.structure_item Versioned_util.diff_formatter inc ;
  Format.pp_print_flush Versioned_util.diff_formatter () ;
  printf "\n%!"

let traverse_ast =
  object (self)
    inherit [accumulator] Ast_traverse.fold as super

    method! structure_item stri acc =
      match stri.pstr_desc with
      | Pstr_module { pmb_name = { txt = Some name; _ }; pmb_expr; _ } ->
          ignore
            (self#module_expr pmb_expr
               { module_path = name :: acc.module_path } ) ;
          acc
      | Pstr_extension ((name, _payload), _attrs)
        when List.mem
               [ "test"; "test_unit"; "test_module" ]
               name.txt ~equal:String.equal ->
          (* don't print functors in test code *)
          acc
      | Pstr_include inc_decl when is_included_binable_functor_app inc_decl ->
          print_included_binable_functor_app ~path:acc.module_path stri ;
          acc
      | _ ->
          super#structure_item stri acc
  end

let preprocess_impl str =
  ignore (traverse_ast#structure str { module_path = [] }) ;
  str

let () =
  Ppxlib.Driver.register_transformation name ~preprocess_impl ;
  Ppxlib.Driver.standalone ()
