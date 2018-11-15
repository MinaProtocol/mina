{
open StdLabels
open Printf

type mode = Generated_code | Source_code

type t =
  { output_fname : string
  ; (* Line number in generated file *)
    mutable line : int
  ; oc           : out_channel
  ; mutable mode : mode
  ; buf          : Buffer.t
  }

let lexeme_len lb =
  Lexing.lexeme_end lb - Lexing.lexeme_start lb

let fail lb msg =
  let start = Lexing.lexeme_start_p lb in
  let stop = Lexing.lexeme_end_p lb in
  Printf.eprintf
    "File %S, line %d, characters %d-%d:\n\
     Error: %s\n%!"
    start.pos_fname start.pos_lnum (start.pos_cnum - start.pos_bol)
    (stop.pos_cnum - start.pos_bol)
    msg;
  exit 1

let ps t s =
  let len = String.length s in
  if len > 0 then
    if s.[len - 1] = '\n' then begin
      assert (String.index s '\n' = len - 1);
      t.line <- t.line + 1;
      if len > 1 && s.[len - 2] = '\r' then begin
        output_substring t.oc s 0 (len - 2);
        output_char t.oc '\n'
      end else
        output_string t.oc s
    end else
      output_string t.oc s
let pc t = function
  | '\n' -> t.line <- t.line + 1; output_char t.oc '\n'
  | '\r' -> assert false
  | c    -> output_char t.oc c
let npc t n c = for _ = 1 to n do pc t c done
let pf t fmt = ksprintf (ps t) fmt

let enter_generated_code t =
  t.mode <- Generated_code;
  pc t '\n';
  pf t "# %d %S\n" (t.line + 1) t.output_fname

let enter_source_code t (pos : Lexing.position) =
  t.mode <- Source_code;
  pc t '\n';
  pf t "# %d %S\n" pos.pos_lnum pos.pos_fname;
  let col = pos.pos_cnum - pos.pos_bol in
  npc t col ' '

let pass_through t lb =
  if t.mode = Generated_code then
    enter_source_code t (Lexing.lexeme_start_p lb);
  ps t (Lexing.lexeme lb)

type and_or_in = And | In
}

let space = [' ' '\t']
let newline = '\n' | "\r\n"
let id =  ['a'-'z' '_'] ['A'-'Z' 'a'-'z' '_' '\'' '0'-'9']*

rule main t col = parse
  | eof
    { In }
  | newline
    { pass_through t lexbuf;
      Lexing.new_line lexbuf;
      after_newline t col lexbuf
    }
  | " in" newline
    { pass_through t lexbuf;
      Lexing.new_line lexbuf;
      after_in_and_newline t col lexbuf
    }
  | _
    { pass_through t lexbuf;
      main t col lexbuf
    }
  | id as id
    { pass_through t lexbuf;
      match id with
      | "let" -> after_let t col (Lexing.lexeme_start_p lexbuf) lexbuf
      | _     -> main t col lexbuf
    }
  | ""
    { fail lexbuf "pp.exe: syntax error" }

and after_let t col pos = parse
  | "%" (id as id)
    { if id <> "map" then begin
        pass_through t lexbuf;
        main t col lexbuf
      end else begin
        let col' = pos.Lexing.pos_cnum - pos.Lexing.pos_bol in
        let rec loop i =
          let pos = Lexing.lexeme_end_p lexbuf in
          enter_generated_code t;
          let id = sprintf "__x%d__" i in
          ps t id;
          lhs t lexbuf;
          let pattern = Buffer.contents t.buf in
          Buffer.clear t.buf;
          (id, (pos, pattern)) ::
          match main t col' lexbuf with
          | And -> loop (i + 1)
          | In  -> []
        in
        let ids, patterns = List.split (loop 1) in
        (* This is generated code, but if we mark it as such, the error
           points to the generated code rather than the source code *)
        enter_source_code t pos;
        ps t "Let_syntax.(fun f -> const f";
        List.iter ids ~f:(pf t " $ %s");
        ps t ") @@ fun ";
        List.iter patterns ~f:(fun (pos, pattern) ->
          pc t '(';
          enter_source_code t pos;
          ps t pattern;
          pc t ')');
        ps t "->";
        t.mode <- Generated_code;
        main t col lexbuf
      end
    }
  | ""
    { main t col lexbuf }

and after_newline t col = parse
  | space*
    { pass_through t lexbuf;
      let len = lexeme_len lexbuf in
      if len = col then
        after_indent t lexbuf
      else if len > col then
        main t col lexbuf
      else
        after_invalid_indent t col lexbuf
    }

and after_invalid_indent t col = parse
  | eof
    { In }
  | newline
    { pass_through t lexbuf;
      after_newline t col lexbuf
    }
  | ""
    { fail lexbuf "invalid indentation after let%map" }

and after_indent t = parse
  | id as id
    { pass_through t lexbuf;
      match id with
      | "and" -> And
      | "in"  -> In
      | _     -> fail lexbuf "'and' or 'in' keyword expected"
    }
  | ""
    { fail lexbuf "'and' or 'in' keyword expected" }

and after_in_and_newline t col = parse
  | space* newline
    { pass_through t lexbuf;
      Lexing.new_line lexbuf;
      after_in_and_newline t col lexbuf
    }
  | space*
    { pass_through t lexbuf;
      if lexeme_len lexbuf = col then
        In
      else
        main t col lexbuf
    }

and lhs t = parse
  | eof
    { ()
    }
  | newline
    { Buffer.add_char t.buf '\n';
      Lexing.new_line lexbuf;
      lhs t lexbuf
    }
  | "="
    { pass_through t lexbuf
    }
  | _ as c
    { Buffer.add_char t.buf c;
      lhs t lexbuf
    }

{
  let create ~output_fname ~oc =
    { output_fname
    ; line = 1
    ; oc
    ; mode = Generated_code
    ; buf = Buffer.create 512
    }

  let print_endline t s =
    if t.mode = Source_code then
      enter_generated_code t;
    ps t s;
    pc t '\n'

  let apply t ~fname =
    let ic = open_in_bin fname in
    let lb = Lexing.from_channel ic in
    lb.lex_curr_p <-
      { pos_fname = fname
      ; pos_lnum  = 1
      ; pos_bol   = 0
      ; pos_cnum  = 0
      };
    t.mode <- Generated_code;
    let (And | In) = main t (-1) lb in
    close_in ic
}
