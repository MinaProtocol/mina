(**************************************************************************)
(*                                                                        *)
(*    Copyright 2016 OCamlPro                                             *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamParserTypes

(** Raw OpamBaseParser main entry point *)
val main:
  (Lexing.lexbuf  -> OpamBaseParser.token) ->
  Lexing.lexbuf -> file_name -> opamfile

val string: string -> file_name -> opamfile

val channel: in_channel -> file_name -> opamfile

val file: file_name -> opamfile
