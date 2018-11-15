open Stdune
(** Dealing with errors *)

(* CR-soon diml: stop including this in [Import] *)
(** This module is included in [Import] *)

(* CR-soon diml: we won't need this once we can generate rules dynamically *)
(** Raised for errors that have already been reported to the user and shouldn't be
    reported again. This might happen when trying to build a dependency that has already
    failed. *)
exception Already_reported

(* CR-soon diml: Rename to [user_errorf]. *)
(** Raise a [Exn.Fatal_error] exception *)
val die : ('a, Format.formatter, unit, 'b) format4 -> 'a

(**/**)
(* Referenced in Ansi_color and Report_error *)
val err_buf : Buffer.t
val err_ppf : Format.formatter
val kerrf
  :  ('a, Format.formatter, unit, 'b) format4
  -> f:(string -> 'b)
  -> 'a

val exnf     : Loc.t         -> ('a, Format.formatter, unit, exn) format4 -> 'a
val fail     : Loc.t         -> ('a, Format.formatter, unit, 'b ) format4 -> 'a
val fail_lex : Lexing.lexbuf -> ('a, Format.formatter, unit, 'b ) format4 -> 'a
val fail_opt : Loc.t option  -> ('a, Format.formatter, unit, 'b ) format4 -> 'a

(** Prints "File ..., line ..., characters ...:\n" *)
val print : Format.formatter -> Loc.t -> unit

(** Prints a warning *)
val warn : Loc.t -> ('a, Format.formatter, unit) format -> 'a

val print_to_console : string -> unit

val printer : (string -> unit) ref
