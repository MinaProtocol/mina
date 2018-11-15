(**************************************************************************)
(*                                                                        *)
(*    Copyright 2012-2015 OCamlPro                                        *)
(*    Copyright 2012 INRIA                                                *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

(** {2 Printers for the [value] and [opamfile] formats} *)

open OpamParserTypes

val relop: relop -> string

val logop: logop -> string

val pfxop: pfxop -> string

val env_update_op: env_update_op -> string

val value : value -> string

val value_list: value list -> string

val items: opamfile_item list -> string

val opamfile: opamfile -> string

val format_opamfile: Format.formatter -> opamfile -> unit

(** {2 Normalised output for opam syntax files} *)

module Normalise : sig
  val escape_string : string -> string
  val value : value -> string
  val item : opamfile_item -> string
  val item_order : opamfile_item -> opamfile_item -> int
  val items : opamfile_item list -> string
  val opamfile : opamfile -> string
end

