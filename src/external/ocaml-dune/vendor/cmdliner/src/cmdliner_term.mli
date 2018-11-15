(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

open Result

(** Terms *)

type term_escape =
  [ `Error of bool * string
  | `Help of Cmdliner_manpage.format * string option ]

type 'a parser =
  Cmdliner_info.eval -> Cmdliner_cline.t ->
  ('a, [ `Parse of string | term_escape ]) result
(** Type type for command line parser. given static information about
    the command line and a command line to parse returns an OCaml value. *)

type 'a t = Cmdliner_info.args * 'a parser
(** The type for terms. The list of arguments it can parse and the parsing
    function that does so. *)

val const : 'a -> 'a t
val app : ('a -> 'b) t -> 'a t -> 'b t

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
