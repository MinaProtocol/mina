(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

(** Messages for the end-user. *)

(** {1:env_err Environment variable errors} *)

val err_env_parse : Cmdliner_info.env -> err:string -> string

(** {1:pos_err Positional argument errors} *)

val err_pos_excess : string list -> string
val err_pos_misses : Cmdliner_info.arg list -> string
val err_pos_parse : Cmdliner_info.arg -> err:string -> string

(** {1:opt_err Optional argument errors} *)

val err_flag_value : string -> string -> string
val err_opt_value_missing : string -> string
val err_opt_parse : string -> err:string -> string
val err_opt_repeated : string -> string -> string

(** {1:arg_err Argument errors} *)

val err_arg_missing : Cmdliner_info.arg -> string

(** {1:msgs Other messages} *)

val pp_version : Format.formatter -> Cmdliner_info.eval -> unit
val pp_try_help : Format.formatter -> Cmdliner_info.eval -> unit
val pp_err : Format.formatter -> Cmdliner_info.eval -> err:string -> unit
val pp_err_usage : Format.formatter -> Cmdliner_info.eval -> err:string -> unit
val pp_backtrace :
  Format.formatter ->
  Cmdliner_info.eval -> exn -> Printexc.raw_backtrace -> unit

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
