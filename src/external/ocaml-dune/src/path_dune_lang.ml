open Stdune
open Path

type t = Path.t

let encode p =
  let arg =
    match Internal.raw_kind p with
    | Kind.External l -> External.to_string l
    | Kind.Local    l -> Local.to_string l
  in
  let make constr =
    Dune_lang.List [ Dune_lang.atom constr
               ; Dune_lang.atom_or_quoted_string arg
               ]
  in
  if is_in_build_dir p then
    make "In_build_dir"
  else if is_in_source_tree p then
    make "In_source_tree"
  else
    make "External"

let decode =
  let open Dune_lang.Decoder in
  let external_ =
    plain_string (fun ~loc t ->
      if Filename.is_relative t then
        Dune_lang.Decoder.of_sexp_errorf loc "Absolute path expected"
      else
        Path.of_string ~error_loc:loc t
    )
  in
  sum
    [ "In_build_dir"  , string    >>| Path.(relative build_dir)
    ; "In_source_tree", string    >>| Path.(relative root)
    ; "External"      , external_
    ]
