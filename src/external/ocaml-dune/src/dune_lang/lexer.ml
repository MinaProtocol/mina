include Lexer_shared

let token = Dune_lexer.token
let jbuild_token = Jbuild_lexer.token

let of_syntax = function
  | Syntax.Dune -> token
  | Jbuild -> jbuild_token
