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

type relop = [ `Eq | `Neq | `Geq | `Gt | `Leq | `Lt ]
type logop = [ `And | `Or ]
type pfxop = [ `Not ]

type file_name = string

(** Source file positions: filename, line, column *)
type pos = file_name * int * int

type env_update_op = Eq | PlusEq | EqPlus | ColonEq | EqColon | EqPlusEq

(** Base values *)
type value =
  | Bool of pos * bool
  | Int of pos * int
  | String of pos * string
  | Relop of pos * relop * value * value
  | Prefix_relop of pos * relop * value
  | Logop of pos * logop * value * value
  | Pfxop of pos * pfxop * value
  | Ident of pos * string
  | List of pos * value list
  | Group of pos * value list
  | Option of pos * value * value list
  | Env_binding of pos * value * env_update_op * value

(** An opamfile section *)
type opamfile_section = {
  section_kind  : string;
  section_name  : string option;
  section_items : opamfile_item list;
}

(** An opamfile is composed of sections and variable definitions *)
and opamfile_item =
  | Section of pos * opamfile_section
  | Variable of pos * string * value

(** A file is a list of items and the filename *)
type opamfile = {
  file_contents: opamfile_item list;
  file_name    : file_name;
}
