{}
rule path acc = parse
  | ":" { path acc lexbuf}
  | "_build/" [^ ':']+
    { path ((Lexing.lexeme lexbuf) :: acc) lexbuf }
  | _ { path acc lexbuf }
  | eof { List.rev acc }

{
  let dune_paths s =
    path [] (Lexing.from_string s)
}
