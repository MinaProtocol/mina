open Core_kernel
open Ppxlib
open Asttypes

(** This is a ppx to check that we're building with an n-bits OCaml

    Usage: [%%check_ocaml_word_size n]

    There will be a compile-time error if the check fails
 *)

let name = "check_ocaml_word_size"

let expand ~loc ~path:_ expected_word_size =
  if not (Int.equal Sys.word_size expected_word_size) then
    Location.raise_errorf ~loc "OCaml word size must be %d, got %d"
      expected_word_size Sys.word_size ;
  [%stri let () = ()]

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (eint __))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
