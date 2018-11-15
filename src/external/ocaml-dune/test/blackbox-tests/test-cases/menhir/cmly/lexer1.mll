{
open Test_menhir1
}

rule lex = parse
  | 'c' { TOKEN 'c' }
  | eof { EOF }
