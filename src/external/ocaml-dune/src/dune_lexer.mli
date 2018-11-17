open! Stdune

(** Returns [true] if the input starts with "(* -*- tuareg -*- *)" *)
val is_script : Lexing.lexbuf -> bool

type first_line =
  { lang    : Loc.t * string
  ; version : Loc.t * string
  }

(** Parse the first line of a versioned file. *)
val first_line : Lexing.lexbuf -> first_line

(** Parse the first line of a versioned file but do not fail if it
    doesn't start with [(lang ...)]. *)
val maybe_first_line : Lexing.lexbuf -> first_line option

val eof_reached : Lexing.lexbuf -> bool
