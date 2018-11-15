
let s = "foo bar baz"

let () =
  let lex1 = Lexing.from_string s in
  let lex2 = Lexing.from_string s in
  ignore (Test_menhir1.main Lexer1.lex lex1);
  ignore (Test_base.main Lexer2.lex lex2)
