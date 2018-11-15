open! Stdune
open Import

type t = Dune_re.re

let decode =
  let open Stanza.Decoder in
  plain_string (fun ~loc str ->
    match Glob_lexer.parse_string str with
    | Ok re ->
      Re.compile re
    | Error (_pos, msg) ->
      Errors.fail loc "invalid glob: %s" msg)

let test t = Re.execp t

let filter t = List.filter ~f:(test t)

let empty = Re.compile Re.empty

let of_re t = Re.compile (Re.seq [Re.bos; t; Re.eos])
