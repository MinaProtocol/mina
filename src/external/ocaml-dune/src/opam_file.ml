open! Stdune
open Import
open OpamParserTypes

type t = opamfile

let load fn =
  Io.with_lexbuf_from_file fn ~f:(fun lb ->
    try
      OpamBaseParser.main OpamLexer.token lb (Path.to_string fn)
    with
    | OpamLexer.Error msg ->
      Errors.fail_lex lb "%s" msg
    | Parsing.Parse_error ->
      Errors.fail_lex lb "Parse error")

let get_field t name =
  List.find_map t.file_contents
    ~f:(function
      | Variable (_, var, value) when name = var ->
        Some value
      | _ -> None)
