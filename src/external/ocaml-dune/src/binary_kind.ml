open! Stdune

type t =
  | C
  | Exe
  | Object
  | Shared_object

let decode =
  let open Dune_lang.Decoder in
  sum
    [ "c"             , Syntax.since Stanza.syntax (1, 2) >>> return C
    ; "exe"           , return Exe
    ; "object"        , return Object
    ; "shared_object" , return Shared_object
    ]

let to_string = function
  | C -> "c"
  | Exe -> "exe"
  | Object -> "object"
  | Shared_object -> "shared_object"

let pp fmt t =
  Format.pp_print_string fmt (to_string t)

let encode t =
  Dune_lang.unsafe_atom_of_string (to_string t)

let all = [C; Exe; Object; Shared_object]
