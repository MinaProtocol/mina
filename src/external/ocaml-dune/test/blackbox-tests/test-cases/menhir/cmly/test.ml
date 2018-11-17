
let s = "foo bar baz"

let () =
  let lex1 = Lexing.from_string s in
  ignore (Test_menhir1.main Lexer1.lex lex1);
