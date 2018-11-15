module Token = struct
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

module Error = struct
  type t =
    { start   : Lexing.position
    ; stop    : Lexing.position
    ; message : string
    }
end

exception Error of Error.t

let error ?(delta=0) lexbuf message =
  let start = Lexing.lexeme_start_p lexbuf in
  raise
    (Error { start = { start with pos_cnum = start.pos_cnum + delta }
           ; stop  = Lexing.lexeme_end_p   lexbuf
           ; message
           })

let escaped_buf = Buffer.create 256

type escape_sequence =
  | Newline
  | Other

let eval_decimal_char c = Char.code c - Char.code '0'

let eval_decimal_escape c1 c2 c3 =
  (eval_decimal_char c1) * 100 +
  (eval_decimal_char c2) * 10  +
  (eval_decimal_char c3)

let eval_hex_char c =
  match c with
  | '0'..'9' -> Char.code c - Char.code '0'
  | 'a'..'f' -> Char.code c - Char.code 'a' + 10
  | 'A'..'F' -> Char.code c - Char.code 'A' + 10
  | _ -> -1

let eval_hex_escape c1 c2 =
  (eval_hex_char c1) * 16 +
  (eval_hex_char c2)
