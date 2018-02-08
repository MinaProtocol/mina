{
open Lexing
open Filter_parser

exception SyntaxError of string

let next_line lexbuf =
  let pos = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <-
    { pos with pos_bol = lexbuf.lex_curr_pos;
               pos_lnum = pos.pos_lnum + 1
    }
}

let int = '-'? ['0'-'9'] ['0'-'9']*

let white = [' ' '\t']+
let newline = '\r' | '\n' | "\r\n"

rule read =
  parse
  | white    { read lexbuf }
  | newline  { next_line lexbuf; read lexbuf }
  | int      { INT (int_of_string (Lexing.lexeme lexbuf)) }
  | "="      { EQUAL }
  | "<>"     { NOT_EQUAL }
  | "info"   { LEVEL_LITERAL Logger.Level.Info }
  | "trace"  { LEVEL_LITERAL Logger.Level.Trace }
  | "debug"  { LEVEL_LITERAL Logger.Level.Debug }
  | "error"  { LEVEL_LITERAL Logger.Level.Error }
  | "fatal"  { LEVEL_LITERAL Logger.Level.Fatal }
  | "warn"   { LEVEL_LITERAL Logger.Level.Warn }
  | "level"  { LEVEL }
  | "pid"    { PID}
  | "host"   { HOST }
  | "true"   { TRUE }
  | "false"  { FALSE }
  | "null"   { NULL }
  | "&&"     { AND }
  | "||"     { OR }
  | '''      { read_string_single_quote (Buffer.create 128) lexbuf }
  | '"'      { read_string (Buffer.create 128) lexbuf }
  | '('      { LEFT_PAREN }
  | ')'      { RIGHT_PAREN }
  | '^'      { CARET }
  | '!'      { NOT }
  | _ { raise (SyntaxError ("Unexpected char: " ^ Lexing.lexeme lexbuf)) }
  | eof      { EOF }

and read_string_single_quote buf =
  parse
  | '\''       { STRING (Buffer.contents buf) }
  | '\\' '/'  { Buffer.add_char buf '/'; read_string_single_quote buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string_single_quote buf lexbuf }
  | '\\' 'b'  { Buffer.add_char buf '\b'; read_string_single_quote buf lexbuf }
  | '\\' 'f'  { Buffer.add_char buf '\012'; read_string_single_quote buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_string_single_quote buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; read_string_single_quote buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_string_single_quote buf lexbuf }
  | [^ '\'' '\\']+
    { Buffer.add_string buf (Lexing.lexeme lexbuf);
      read_string_single_quote buf lexbuf
    }
  | _ { raise (SyntaxError ("Illegal string character: " ^ Lexing.lexeme lexbuf)) }
| eof { raise (SyntaxError ("String is not terminated")) }

and read_string buf =
  parse
  | '"'       { STRING (Buffer.contents buf) }
  | '\\' '/'  { Buffer.add_char buf '/'; read_string buf lexbuf }
  | '\\' '\\' { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | '\\' 'b'  { Buffer.add_char buf '\b'; read_string buf lexbuf }
  | '\\' 'f'  { Buffer.add_char buf '\012'; read_string buf lexbuf }
  | '\\' 'n'  { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | '\\' 'r'  { Buffer.add_char buf '\r'; read_string buf lexbuf }
  | '\\' 't'  { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | [^ '"' '\\']+
    { Buffer.add_string buf (Lexing.lexeme lexbuf);
      read_string buf lexbuf
    }
  | _ { raise (SyntaxError ("Illegal string character: " ^ Lexing.lexeme lexbuf)) }
| eof { raise (SyntaxError ("String is not terminated")) }
