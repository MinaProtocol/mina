{
open! Stdune
module Re = Dune_re
open Re

let no_slash        = diff any (char '/')
let no_slash_no_dot = diff any (set "./")

type stack =
  | Bottom
  | Lbrace of stack
  | Re     of Re.t * stack
  | Comma  of stack

let make_group st =
  let rec loop current_re full_res st =
    match st with
    | Bottom      -> failwith "'}' without opening '{'"
    | Re (re, st) -> loop (re :: current_re) full_res st
    | Comma   st  -> loop [] (seq current_re :: full_res) st
    | Lbrace  st  -> Re (alt (seq current_re :: full_res), st)
  in
  loop [] [] st

let finalize st =
  let rec loop acc st =
    match st with
    | Bottom      -> seq (start :: acc)
    | Re (re, st) -> loop (re       :: acc) st
    | Comma   st  -> loop (char ',' :: acc) st
    | Lbrace  _   -> failwith "unclosed '{'"
  in
  loop [stop] st
}

rule initial = parse
  | "**" { glob (Re (rep any, Bottom)) lexbuf }
  | "*"  { glob (Re (seq [no_slash_no_dot; rep no_slash], Bottom)) lexbuf }
  | ""   { glob Bottom lexbuf }

and glob st = parse
  | eof
  | '\\' eof      { finalize st }
  | '\\' (_ as c) { glob (Re (char c                              , st)) lexbuf }
  | "**"          { glob (Re (seq [no_slash_no_dot; rep no_slash] , st)) lexbuf }
  | '*'           { glob (Re (rep no_slash                        , st)) lexbuf }
  | '?'           { glob (Re (no_slash                            , st)) lexbuf }
  | '{'           { glob (Lbrace                                    st ) lexbuf }
  | ','           { glob (Comma                                     st ) lexbuf }
  | '}'           { glob (make_group st)                                 lexbuf }
  | '['           { char_set st                                          lexbuf }
  | ']'           { failwith "']' without opening '['"                          }
  | _ as c        { glob (Re (char c                              , st)) lexbuf }

and char_set st = parse
  | '!' ([^ ']']* as s) "]" { glob (Re (diff any (set s) , st)) lexbuf }
  |     ([^ ']']* as s) "]" { glob (Re (set s            , st)) lexbuf }
  | ""                     { failwith "unclosed character set"        }

{
  let parse_string s =
    let lb = Lexing.from_string s in
    match initial lb with
    | re -> Result.Ok re
    | exception Failure msg ->
      Error (Lexing.lexeme_start lb, msg)
}

