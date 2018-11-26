(**************************************************************************)
(*                                                                        *)
(*    Copyright 2012-2015 OCamlPro                                        *)
(*    Copyright 2012 INRIA                                                *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

{

open OpamParserTypes
open OpamBaseParser

exception Error of string

let newline lexbuf = Lexing.new_line lexbuf
let error fmt =
  Printf.kprintf (fun msg -> raise (Error msg)) fmt

let relop = function
  | "="  -> `Eq
  | "!=" -> `Neq
  | ">=" -> `Geq
  | ">"  -> `Gt
  | "<=" -> `Leq
  | "<"  -> `Lt
  | x    -> error "%S is not a valid comparison operator" x

let logop = function
  | "&" -> `And
  | "|" -> `Or
  | x -> error "%S is not a valid logical operator" x

let pfxop = function
  | "!" -> `Not
  | x -> error "%S is not a valid prefix operator" x

let env_update_op = function
  | "=" -> Eq
  | "+=" -> PlusEq
  | "=+" -> EqPlus
  | "=+=" -> EqPlusEq
  | ":=" -> ColonEq
  | "=:" -> EqColon
  | x -> error "%S is not a valid environment update operator" x

let char_for_backslash = function
  | 'n' -> '\010'
  | 'r' -> '\013'
  | 'b' -> '\008'
  | 't' -> '\009'
  | c   -> c

let char_for_decimal_code lexbuf i =
  let c = 100 * (Char.code(Lexing.lexeme_char lexbuf i) - 48) +
           10 * (Char.code(Lexing.lexeme_char lexbuf (i+1)) - 48) +
                (Char.code(Lexing.lexeme_char lexbuf (i+2)) - 48) in
  if (c < 0 || c > 255) then error "illegal escape sequence" ;
  Char.chr c

let char_for_hexadecimal_code lexbuf i =
  let d1 = Char.code (Lexing.lexeme_char lexbuf i) in
  let val1 = if d1 >= 97 then d1 - 87
             else if d1 >= 65 then d1 - 55
             else d1 - 48 in
  let d2 = Char.code (Lexing.lexeme_char lexbuf (i+1)) in
  let val2 = if d2 >= 97 then d2 - 87
             else if d2 >= 65 then d2 - 55
             else d2 - 48 in
  Char.chr (val1 * 16 + val2)

let buffer_rule r lb =
  let b = Buffer.create 64 in
  r b lb ;
  Buffer.contents b
}

let space  = [' ' '\t' '\r']

let alpha  = ['a'-'z' 'A'-'Z']
let digit  = ['0'-'9']

let ichar  = alpha | digit | ['_' '-']
let id     = ichar* alpha ichar*
let ident  = (id | '_') ('+' (id | '_'))* (':' id)?

let relop  = ('!'? '=' | [ '<' '>' ] '='?)
let pfxop  = '!'
let envop_char = [ '+' ':' ]
let envop = (envop_char '=' | '=' envop_char '='?)
let int    = ('-'? ['0'-'9' '_']+)

rule token = parse
| space  { token lexbuf }
| '\n'   { newline lexbuf; token lexbuf }
| ":"    { COLON }
| "{"    { LBRACE }
| "}"    { RBRACE }
| "["    { LBRACKET }
| "]"    { RBRACKET }
| "("    { LPAR }
| ")"    { RPAR }
| '\"'   { STRING (buffer_rule string lexbuf) }
| "\"\"\"" { STRING (buffer_rule string_triple lexbuf) }
| "(*"   { comment 1 lexbuf; token lexbuf }
| "#"    { comment_line lexbuf; token lexbuf }
| "true" { BOOL true }
| "false"{ BOOL false }
| int    { INT (int_of_string (Lexing.lexeme lexbuf)) }
| ident  { IDENT (Lexing.lexeme lexbuf) }
| relop  { RELOP (relop (Lexing.lexeme lexbuf)) }
| '&'    { AND }
| '|'    { OR }
| pfxop  { PFXOP (pfxop (Lexing.lexeme lexbuf)) }
| envop  { ENVOP (env_update_op (Lexing.lexeme lexbuf)) }
| eof    { EOF }
| _      { let token = Lexing.lexeme lexbuf in
           error "'%s' is not a valid token" token }

and string b = parse
| '\"'    { () }
| '\n'    { newline lexbuf ;
            Buffer.add_char b '\n'            ; string b lexbuf }
| '\\'    { (match escape lexbuf with
            | Some c -> Buffer.add_char b c
            | None -> ());
            string b lexbuf }
| _ as c  { Buffer.add_char b c               ; string b lexbuf }
| eof     { error "unterminated string" }

and string_triple b = parse
| "\"\"\""    { () }
| '\n'    { newline lexbuf ;
            Buffer.add_char b '\n'            ; string_triple b lexbuf }
| '\\'    { (match escape lexbuf with
            | Some c -> Buffer.add_char b c
            | None -> ());
            string_triple b lexbuf }
| _ as c  { Buffer.add_char b c               ; string_triple b lexbuf }
| eof     { error "unterminated string" }

and escape = parse
| '\n' space *
          { newline lexbuf; None }
| ['\\' '\"' ''' 'n' 'r' 't' 'b' ' '] as c
          { Some (char_for_backslash c) }
| digit digit digit
          { Some (char_for_decimal_code lexbuf 0) }
| 'x' ['0'-'9''a'-'f''A'-'F'] ['0'-'9''a'-'f''A'-'F']
          { Some (char_for_hexadecimal_code lexbuf 1) }
| ""      { error "illegal escape sequence" }

and comment n = parse
| "*)" { if n > 1 then comment (n-1) lexbuf }
| "(*" { comment (n+1)lexbuf }
| eof  { error "unterminated comment" }
| '\n' { newline lexbuf; comment n lexbuf }
| _    { comment n lexbuf }

and comment_line = parse
| [^'\n']* '\n' { newline lexbuf }
| [^'\n']       { () }
