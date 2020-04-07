[%%import
"/src/config.mlh"]

(* print_binable_functors.ml *)

(* print out applications of functors Binable.Of... or Bin_prot.Utils.Make_binable

   within a versioned type, these should not change
   and they should always appear within a versioned type

*)

open Core_kernel
open Ppxlib

let name = "print_binable_functors"

type accumulator = {module_path: string list}

let is_included_binable_functor_app (inc_decl : include_declaration) =
  match inc_decl with
  | { pincl_mod=
        { pmod_desc=
            Pmod_apply
              ( { pmod_desc=
                    Pmod_apply
                      ( { pmod_desc=
                            Pmod_ident
                              {txt= Ldot (Lident "Binable", binable_functor); _}
                        ; _ }
                      , _ )
                ; _ }
              , _ )
        ; _ }
    ; _ } ->
      List.mem
        [ "Of_binable"
        ; "Of_binable1"
        ; "Of_binable2"
        ; "Of_binable3"
        ; "Of_sexpable"
        ; "Of_stringable" ]
        binable_functor ~equal:String.equal
  | { pincl_mod=
        { pmod_desc=
            Pmod_apply
              ( { pmod_desc=
                    Pmod_ident
                      { txt=
                          Ldot
                            (Ldot (Lident "Bin_prot", "Utils"), "Make_binable")
                      ; _ }
                ; _ }
              , _ )
        ; _ }
    ; _ } ->
      true
  | _ ->
      false

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
      | Pstr_module {pmb_name; pmb_expr; _} ->
          ignore
            (self#module_expr pmb_expr
               {module_path= pmb_name.txt :: acc.module_path}) ;
          acc
      | Pstr_extension ((name, _payload), _attrs)
        when String.equal name.txt "test_module" ->
          (* don't print functors in test code *)
          acc
      | Pstr_include inc_decl when is_included_binable_functor_app inc_decl ->
          print_included_binable_functor_app ~path:acc.module_path stri ;
          acc
      | _ ->
          super#structure_item stri acc
  end

let preprocess_impl str =
  ignore (traverse_ast#structure str {module_path= []}) ;
  str

let () =
  match Sys.getenv_opt "CODA_PRINT_BINABLE_FUNCTORS" with
  | Some "true" ->
      Ppxlib.Driver.register_transformation name ~preprocess_impl
  | _ ->
      ()
