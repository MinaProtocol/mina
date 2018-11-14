open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

let expr_of_sexp ~loc s =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let rec go (s : Sexp.t) =
    match s with
    | Atom s -> [%expr Sexplib.Sexp.Atom [%e estring s]]
    | List xs -> [%expr Sexplib.Sexp.List [%e elist (List.map ~f:go xs)]]
  in
  go s
