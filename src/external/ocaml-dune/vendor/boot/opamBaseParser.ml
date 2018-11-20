open OpamParserTypes
let main _lex _lexbuf fn =
  assert (fn = "dune.opam" || fn = "jbuilder.opam");
  { file_contents = []
  ; file_name     = fn
  }
