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

val token : t
val jbuild_token : t

val of_syntax : Syntax.t -> t

module Error : sig
  type t =
    { start   : Lexing.position
    ; stop    : Lexing.position
    ; message : string
    }
end

exception Error of Error.t
