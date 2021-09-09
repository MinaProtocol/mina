open Core_kernel
open Ppxlib
open Asttypes

(** This is a ppx to flag code that will expire after a certain date

    Motivation: RFC 0012 indicates that RPC versions should eventually expire, in order
     to encourage nodes to upgrade their software

    Usage: [%%expires_after "20201231"]

    There will be a compile-time error if
      - the date of compilation is past the given date, or
      - the date is not of the form YYYYMMDD
 *)

let name = "expires_after"

let expand ~loc ~path:_ str _delimiter =
  let date =
    try
      (* the of_string function below allows too-long strings, as long as it starts
         with a valid date, so we do our own length check
        *)
      if String.length str.txt > 8 then
        Location.raise_errorf ~loc:str.loc
          "Not a valid date, string too long; must be in form YYYYMMDD" ;
      Core_kernel.Date.of_string_iso8601_basic ~pos:0 str.txt
    with _ ->
      Location.raise_errorf ~loc:str.loc
        "Not a valid date; must be in form YYYYMMDD"
  in
  let today = Date.today ~zone:Time.Zone.utc in
  if Date.( >= ) today date then
    Location.raise_errorf ~loc:str.loc "Code is expired" ;
  [%stri let () = ()]

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (pexp_constant (pconst_string __' __)))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
