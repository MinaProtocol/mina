(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

(** Manpages.

    See {!Cmdliner.Manpage}. *)

type block =
  [ `S of string | `P of string | `Pre of string | `I of string * string
  | `Noblank | `Blocks of block list ]

val escape : string -> string
(** [escape s] escapes [s] from the doc language. *)

type title = string * int * string * string * string

type t = title * block list

type xref =
  [ `Main | `Cmd of string | `Tool of string | `Page of string * int ]

(** {1 Standard section names} *)

val s_name : string
val s_synopsis : string
val s_description : string
val s_commands : string
val s_arguments : string
val s_options : string
val s_common_options : string
val s_exit_status : string
val s_environment : string
val s_files : string
val s_bugs : string
val s_examples : string
val s_authors : string
val s_see_also : string

(** {1 Section maps}

    Used for handling the merging of metadata doc strings. *)

type smap
val smap_of_blocks : block list -> smap
val smap_to_blocks : smap -> block list
val smap_has_section : smap -> sec:string -> bool
val smap_append_block : smap -> sec:string -> block -> smap
(** [smap_append_block smap sec b] appends [b] at the end of section
    [sec] creating it at the right place if needed. *)

(** {1 Content boilerplate} *)

val s_exit_status_intro : block
val s_environment_intro : block

(** {1 Output} *)

type format = [ `Auto | `Pager | `Plain | `Groff ]
val print :
  ?errs:Format.formatter -> ?subst:(string -> string option) -> format ->
  Format.formatter -> t -> unit

(** {1 Printers and escapes used by Cmdliner module} *)

val subst_vars :
  errs:Format.formatter -> subst:(string -> string option) -> Buffer.t ->
  string -> string
(** [subst b ~subst s], using [b], substitutes in [s] variables of the form
    "$(doc)" by their [subst] definition. This leaves escapes and markup
    directives $(markup,...) intact.

    @raise Invalid_argument in case of illegal syntax. *)

val doc_to_plain :
  errs:Format.formatter -> subst:(string -> string option) -> Buffer.t ->
  string -> string
(** [doc_to_plain b ~subst s] using [b], subsitutes in [s] variables by
    their [subst] definition and renders cmdliner directives to plain
    text.

    @raise Invalid_argument in case of illegal syntax. *)

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
