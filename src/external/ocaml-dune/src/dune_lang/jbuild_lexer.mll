{
  open Lexer_shared

(* The difference between the old and new syntax is that the old
   syntax allows backslash following by any characters other than 'n',
   'x', ... and interpret it as it. The new syntax is stricter in
   order to allow introducing new escape sequence in the future if
   needed. *)
type escape_mode =
  | In_block_comment (* Inside #|...|# comments (old syntax) *)
  | In_quoted_string
}

let comment   = ';' [^ '\n' '\r']*
let newline   = '\r'? '\n'
let blank     = [' ' '\t' '\012']
let digit     = ['0'-'9']
let hexdigit  = ['0'-'9' 'a'-'f' 'A'-'F']

let atom_char =
  [^ ';' '(' ')' '"' ' ' '\t' '\r' '\n' '\012']

(* rule for jbuild files *)
rule token = parse
  | newline
    { Lexing.new_line lexbuf; token lexbuf }
  | blank+ | comment
    { token lexbuf }
  | '('
    { Token.Lparen }
  | ')'
    { Rparen }
  | '"'
    { Buffer.clear escaped_buf;
      let start = Lexing.lexeme_start_p lexbuf in
      let s = quoted_string In_quoted_string lexbuf in
      lexbuf.lex_start_p <- start;
      Quoted_string s
    }
  | "#|"
    { block_comment lexbuf;
      token lexbuf
    }
  | "#;"
    { Sexp_comment }
  | eof
    { Eof }
  | ""
    { atom "" (Lexing.lexeme_start_p lexbuf) lexbuf }

and atom acc start = parse
  | '#'+ '|'
    { lexbuf.lex_start_p <- start;
      error lexbuf "jbuild atoms cannot contain #|"
    }
  | '|'+ '#'
    { lexbuf.lex_start_p <- start;
      error lexbuf "jbuild atoms cannot contain |#"
    }
  | ('#'+ | '|'+ | (atom_char # ['|' '#'])) as s
    { atom (if acc = "" then s else acc ^ s) start lexbuf
    }
  | ""
    { if acc = "" then
        error lexbuf "Internal error in the S-expression parser, \
                      please report upstream.";
      lexbuf.lex_start_p <- start;
      Token.Atom (Atom.of_string acc)
    }

and quoted_string mode = parse
  | '"'
    { Buffer.contents escaped_buf }
  | '\\'
    { match escape_sequence mode lexbuf with
      | Newline -> quoted_string_after_escaped_newline mode lexbuf
      | Other   -> quoted_string                       mode lexbuf
    }
  | newline as s
    { Lexing.new_line lexbuf;
      Buffer.add_string escaped_buf s;
      quoted_string mode lexbuf
    }
  | _ as c
    { Buffer.add_char escaped_buf c;
      quoted_string mode lexbuf
    }
  | eof
    { if mode = In_block_comment then
        error lexbuf "unterminated quoted string";
      Buffer.contents escaped_buf
    }

and quoted_string_after_escaped_newline mode = parse
  | [' ' '\t']*
    { quoted_string mode lexbuf }

and block_comment = parse
  | '"'
    { Buffer.clear escaped_buf;
      ignore (quoted_string In_block_comment lexbuf : string);
      block_comment lexbuf
    }
  | "|#"
    { ()
    }
  | eof
    { error lexbuf "unterminated block comment"
    }
  | _
    { block_comment lexbuf
    }

and escape_sequence mode = parse
  | newline
    { Lexing.new_line lexbuf;
      Newline }
  | ['\\' '\'' '"' 'n' 't' 'b' 'r'] as c
    { let c =
        match c with
        | 'n' -> '\n'
        | 'r' -> '\r'
        | 'b' -> '\b'
        | 't' -> '\t'
        | _   -> c
      in
      Buffer.add_char escaped_buf c;
      Other
    }
  | (digit as c1) (digit as c2) (digit as c3)
    { let v = eval_decimal_escape c1 c2 c3 in
      if mode = In_quoted_string && v > 255 then
        error lexbuf "escape sequence in quoted string out of range"
          ~delta:(-1);
      Buffer.add_char escaped_buf (Char.chr v);
      Other
    }
  | digit* as s
    { if mode = In_quoted_string then
        error lexbuf "unterminated decimal escape sequence" ~delta:(-1);
      Buffer.add_char escaped_buf '\\';
      Buffer.add_string escaped_buf s;
      Other
    }
  | 'x' (hexdigit as c1) (hexdigit as c2)
    { let v = eval_hex_escape c1 c2 in
      Buffer.add_char escaped_buf (Char.chr v);
      Other
    }
  | 'x' hexdigit* as s
    { if mode = In_quoted_string then
        error lexbuf "unterminated hexadecimal escape sequence" ~delta:(-1);
      Buffer.add_char escaped_buf '\\';
      Buffer.add_string escaped_buf s;
      Other
    }
  | _ as c
    { Buffer.add_char escaped_buf '\\';
      Buffer.add_char escaped_buf c;
      Other
    }
  | eof
    { if mode = In_quoted_string then
        error lexbuf "unterminated escape sequence" ~delta:(-1);
      Other
    }
