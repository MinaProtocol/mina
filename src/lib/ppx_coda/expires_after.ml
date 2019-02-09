open Core_kernel
open Ppxlib
open Asttypes

(** This is a ppx to flag code that will expire after a certain date

    Motivation: RFC 0012 indicates that RPC versions should eventually expire, in order
     to encourage nodes to upgrade their software

    Usage (at top-level): let _ = [%%expires_after "20201231"]

    There will be a compile-time error if 
      - the date of compilation is past the given date, or
      - the date is not of the form YYYYMMDD
 *)

let name = "expires_after"

let expand ~loc ~path:_ s =
  let date =
    try Date.of_string_iso8601_basic s ~pos:0 with _ ->
      Location.raise_errorf ~loc "Not a valid date; must be in form YYYYMMDD"
  in
  let today = Date.today ~zone:Time.Zone.utc in
  if Date.( >= ) today date then Location.raise_errorf ~loc "Code is expired"
  else
    [%expr
      let _ = () in
      ()]

let ext =
  Extension.declare name Extension.Context.expression
    Ast_pattern.(single_expr_payload (estring __))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
