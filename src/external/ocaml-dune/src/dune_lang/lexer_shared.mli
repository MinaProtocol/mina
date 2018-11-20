module Token : sig
  type t =
    | Atom          of Atom.t
    | Quoted_string of string
    | Lparen
    | Rparen
    | Sexp_comment
    | Eof
    | Template of Template.t
end

type t = Lexing.lexbuf -> Token.t

module Error : sig
  type t =
    { start   : Lexing.position
    ; stop    : Lexing.position
    ; message : string
    }
end

val error : ?delta:int -> Lexing.lexbuf -> string -> 'a

val escaped_buf : Buffer.t

exception Error of Error.t

type escape_sequence =
  | Newline
  | Other

val eval_decimal_char : char -> int

val eval_decimal_escape : char -> char -> char -> int

val eval_hex_escape : char -> char -> int
