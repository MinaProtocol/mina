{
}

rule lex = parse
  | _   { true  }
  | eof { false }
