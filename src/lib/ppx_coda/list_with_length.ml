open Ppxlib

let name = "list_with_length"

(* TODO: [%%list_with_length 42 some_type] *)

let expand ~loc ~path:_ n =
  let module E = Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  ptyp_constr
    {txt= Longident.parse ("List_with_length.M_" ^ string_of_int n ^ ".t"); loc}
    []

let ext =
  Extension.declare name Extension.Context.core_type
    Ast_pattern.(pstr (pstr_eval (eint __) nil ^:: pstr_type __ __ ^:: nil))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
