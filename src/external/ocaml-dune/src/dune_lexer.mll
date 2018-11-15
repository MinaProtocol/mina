{
open! Stdune
type first_line =
  { lang    : Loc.t * string
  ; version : Loc.t * string
  }

let make_loc lexbuf : Loc.t =
  { start = Lexing.lexeme_start_p lexbuf
  ; stop  = Lexing.lexeme_end_p   lexbuf
  }

let invalid_lang_line start lexbuf =
  lexbuf.Lexing.lex_start_p <- start;
  Errors.fail_lex lexbuf
    "Invalid first line, expected: (lang <lang> <version>)"
}

let newline   = '\r'? '\n'
let blank     = [' ' '\t']
let atom_char = [^';' '(' ')' '"' '#' '|' '\000'-'\032']

rule is_script = parse
  | "(* -*- tuareg -*- *)" { true }
  | ""                     { false }

and maybe_first_line = parse
  | '(' blank* "lang"
    { let start = Lexing.lexeme_start_p lexbuf in
      let lang    = atom start lexbuf in
      let version = atom start lexbuf in
      first_line_rparen_end start lexbuf;
      Some { lang; version }
    }
  | ""
    { None
    }

and atom start = parse
  | blank+
    { atom start lexbuf
    }
  | atom_char+ as s
    { (make_loc lexbuf, s)
    }
  | _ | eof
    { to_eol lexbuf;
      invalid_lang_line start lexbuf
    }

and first_line_rparen_end start = parse
  | blank* ')' blank* (newline | eof as s)
    { if s <> "" then Lexing.new_line lexbuf
    }
  | ""
    { to_eol lexbuf;
      invalid_lang_line start lexbuf
    }

and to_eol = parse
  | [^'\r' '\n']*
    { ()
    }

and eof_reached = parse
  | eof { true  }
  | ""  { false }

{
  let first_line lb =
    match maybe_first_line lb with
    | Some x -> x
    | None ->
      let start = Lexing.lexeme_start_p lb in
      to_eol lb;
      invalid_lang_line start lb
}
