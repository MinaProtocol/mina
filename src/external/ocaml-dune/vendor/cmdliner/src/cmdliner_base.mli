(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

(** A few helpful base definitions. *)

(** {1:str String helpers} *)

val lowercase : string -> string
val uppercase : string -> string
val capitalize : string -> string

(** {1:fmt Formatting helpers} *)

val pp_text : Format.formatter -> string -> unit
val pp_lines : Format.formatter -> string -> unit
val pp_tokens : spaces:bool -> Format.formatter -> string -> unit

(** {1:err Error message helpers} *)

val quote : string -> string
val alts_str : ?quoted:bool -> string list -> string
val err_ambiguous : kind:string -> string -> ambs:string list -> string
val err_unknown : ?hints:string list -> kind:string -> string -> string
val err_multi_def :
  kind:string -> string -> ('b -> string) -> 'b -> 'b -> string

(** {1:conv Textual OCaml value converters} *)

type 'a parser = string -> [ `Ok of 'a | `Error of string ]
type 'a printer = Format.formatter -> 'a -> unit
type 'a conv = 'a parser * 'a printer

val some : ?none:string -> 'a conv -> 'a option conv
val bool : bool conv
val char : char conv
val int : int conv
val nativeint : nativeint conv
val int32 : int32 conv
val int64 : int64 conv
val float : float conv
val string : string conv
val enum : (string * 'a) list -> 'a conv
val file : string conv
val dir : string conv
val non_dir_file : string conv
val list : ?sep:char -> 'a conv -> 'a list conv
val array : ?sep:char -> 'a conv -> 'a array conv
val pair : ?sep:char -> 'a conv -> 'b conv -> ('a * 'b) conv
val t2 : ?sep:char -> 'a conv -> 'b conv -> ('a * 'b) conv
val t3 : ?sep:char -> 'a conv ->'b conv -> 'c conv -> ('a * 'b * 'c) conv
val t4 :
  ?sep:char -> 'a conv -> 'b conv -> 'c conv -> 'd conv ->
  ('a * 'b * 'c * 'd) conv

val env_bool_parse : bool parser

(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
