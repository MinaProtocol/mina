{
type token =
  | Name   of string
  | String of string
  | Minus
  | Lparen
  | Rparen
  | Comma
  | Equal
  | Plus_equal
  | Eof

let escaped_buf = Buffer.create 256
}

rule token = parse
  | [' ' '\t' '\r']* { token lexbuf }
  | '#' [^ '\n']* { token lexbuf }
  | '\n' { Lexing.new_line lexbuf; token lexbuf }

  | ['A'-'Z' 'a'-'z' '0'-'9' '_' '.']+ as s { Name s }
  | '"'
      { Buffer.clear escaped_buf;
        string escaped_buf lexbuf }
  | '-' { Minus }
  | '(' { Lparen }
  | ')' { Rparen }
  | ',' { Comma }
  | '=' { Equal }
  | "+=" { Plus_equal }
  | eof { Eof }
  | _ { Errors.fail_lex lexbuf "invalid character" }

and string buf = parse
  | '"'
      { String (Buffer.contents buf) }
  | "\\\n"
  | '\n'
      { Lexing.new_line lexbuf;
        Buffer.add_char buf '\n';
        string buf lexbuf }
  | '\\' (_ as c)
  | (_ as c)
      { Buffer.add_char buf c;
        string buf lexbuf }
  | eof
      { Errors.fail_lex lexbuf "unterminated string" }
