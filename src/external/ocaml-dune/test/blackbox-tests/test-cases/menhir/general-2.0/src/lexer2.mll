{
open Test_base
}

rule lex = parse
  | 'c' { TOKEN 'c' }
  | eof { EOF }
