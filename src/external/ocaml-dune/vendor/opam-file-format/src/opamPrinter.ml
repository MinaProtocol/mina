(**************************************************************************)
(*                                                                        *)
(*    Copyright 2012-2016 OCamlPro                                        *)
(*    Copyright 2012 INRIA                                                *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open OpamParserTypes

let relop = function
  | `Eq  -> "="
  | `Neq -> "!="
  | `Geq -> ">="
  | `Gt  -> ">"
  | `Leq -> "<="
  | `Lt  -> "<"

let logop = function
  | `And -> "&"
  | `Or -> "|"

let pfxop = function
  | `Not -> "!"

let env_update_op = function
  | Eq -> "="
  | PlusEq -> "+="
  | EqPlus -> "=+"
  | EqPlusEq -> "=+="
  | ColonEq -> ":="
  | EqColon -> "=:"

let escape_string ?(triple=false) s =
  let len = String.length s in
  let buf = Buffer.create (len * 2) in
  for i = 0 to len -1 do
    let c = s.[i] in
    (match c with
     | '"'
       when not triple
         || (i < len - 2 && s.[i+1] = '"' && s.[i+2] = '"')
         || i = len - 1 ->
       Buffer.add_char buf '\\'
     | '\\' -> Buffer.add_char buf '\\'
     | _ -> ());
    Buffer.add_char buf c
  done;
  Buffer.contents buf

let rec format_value fmt = function
  | Relop (_,op,l,r) ->
    Format.fprintf fmt "@[<h>%a %s@ %a@]"
      format_value l (relop op) format_value r
  | Logop (_,op,l,r) ->
    Format.fprintf fmt "@[<hv>%a %s@ %a@]"
      format_value l (logop op) format_value r
  | Pfxop (_,op,r) ->
    Format.fprintf fmt "@[<h>%s%a@]" (pfxop op) format_value r
  | Prefix_relop (_,op,r) ->
    Format.fprintf fmt "@[<h>%s@ %a@]"
      (relop op) format_value r
  | Ident (_,s)     -> Format.fprintf fmt "%s" s
  | Int (_,i)       -> Format.fprintf fmt "%d" i
  | Bool (_,b)      -> Format.fprintf fmt "%b" b
  | String (_,s)    ->
    if String.contains s '\n'
    then Format.fprintf fmt "\"\"\"\n%s\"\"\""
        (escape_string ~triple:true s)
    else Format.fprintf fmt "\"%s\"" (escape_string s)
  | List (_, l) ->
    Format.fprintf fmt "@[<hv>[@;<0 2>@[<hv>%a@]@,]@]" format_values l
  | Group (_,g)     -> Format.fprintf fmt "@[<hv>(%a)@]" format_values g
  | Option(_,v,l)   -> Format.fprintf fmt "@[<hov 2>%a@ {@[<hv>%a@]}@]"
                         format_value v format_values l
  | Env_binding (_,id,op,v) ->
    Format.fprintf fmt "@[<h>%a %s@ %a@]"
      format_value id (env_update_op op) format_value v

and format_values fmt = function
  | [] -> ()
  | [v] -> format_value fmt v
  | v::r ->
    format_value fmt v;
    Format.pp_print_space fmt ();
    format_values fmt r

let value v =
  format_value Format.str_formatter v; Format.flush_str_formatter ()

let value_list vl =
  Format.fprintf Format.str_formatter "@[<hv>%a@]" format_values vl;
  Format.flush_str_formatter ()

let rec format_item fmt = function
  | Variable (_, _, List (_,[])) -> ()
  | Variable (_, _, List (_,[List(_,[])])) -> ()
  | Variable (_, i, List (_,l)) ->
    if List.exists
        (function List _ | Option (_,_,_::_) -> true | _ -> false)
        l
    then Format.fprintf fmt "@[<v>%s: [@;<0 2>@[<v>%a@]@,]@]"
        i format_values l
    else Format.fprintf fmt "@[<hv>%s: [@;<0 2>@[<hv>%a@]@,]@]"
        i format_values l
  | Variable (_, i, (String (_,s) as v)) when String.contains s '\n' ->
    Format.fprintf fmt "@[<hov 0>%s: %a@]" i format_value v
  | Variable (_, i, v) ->
    Format.fprintf fmt "@[<hov 2>%s:@ %a@]" i format_value v
  | Section (_,s) ->
    Format.fprintf fmt "@[<v 0>%s %s{@;<0 2>@[<v>%a@]@,}@]"
      s.section_kind
      (match s.section_name with
       | Some s -> Printf.sprintf "\"%s\" " (escape_string s)
       | None -> "")
      format_items s.section_items
and format_items fmt is =
  Format.pp_open_vbox fmt 0;
  (match is with
   | [] -> ()
   | i::r ->
     format_item fmt i;
     List.iter (fun i -> Format.pp_print_cut fmt (); format_item fmt i) r);
  Format.pp_close_box fmt ()

let format_opamfile fmt f =
  format_items fmt f.file_contents;
  Format.pp_print_newline fmt ()

let items l =
  format_items Format.str_formatter l; Format.flush_str_formatter ()

let opamfile f =
  items f.file_contents

module Normalise = struct
  (** OPAM normalised file format, for signatures:
      - each top-level field on a single line
      - file ends with a newline
      - spaces only after [fieldname:], between elements in lists, before braced
        options, between operators and their operands
      - fields are sorted lexicographically by field name (using [String.compare])
      - newlines in strings turned to ['\n'], backslashes and double quotes
        escaped
      - no comments (they don't appear in the internal file format anyway)
      - fields containing an empty list, or a singleton list containing an empty
        list, are not printed at all
  *)

  let escape_string s =
    let len = String.length s in
    let buf = Buffer.create (len * 2) in
    Buffer.add_char buf '"';
    for i = 0 to len -1 do
      match s.[i] with
      | '\\' | '"' as c -> Buffer.add_char buf '\\'; Buffer.add_char buf c
      | '\n' -> Buffer.add_string buf "\\n"
      | c -> Buffer.add_char buf c
    done;
    Buffer.add_char buf '"';
    Buffer.contents buf

  let rec value = function
    | Relop (_,op,l,r) ->
      String.concat " " [value l; relop op; value r]
    | Logop (_,op,l,r) ->
      String.concat " " [value l; logop op; value r]
    | Pfxop (_,op,r) ->
      String.concat " " [pfxop op; value r]
    | Prefix_relop (_,op,r) ->
      String.concat " " [relop op; value r]
    | Ident (_,s) -> s
    | Int (_,i) -> string_of_int i
    | Bool (_,b) -> string_of_bool b
    | String (_,s) -> escape_string s
    | List (_, l) -> Printf.sprintf "[%s]" (String.concat " " (List.map value l))
    | Group (_,g) -> Printf.sprintf "(%s)" (String.concat " " (List.map value g))
    | Option(_,v,l) ->
      Printf.sprintf "%s {%s}" (value v) (String.concat " " (List.map value l))
    | Env_binding (_,id,op,v) ->
      String.concat " "
        [value id; env_update_op op; value v]

  let rec item = function
    | Variable (_, _, List (_,([]|[List(_,[])]))) -> ""
    | Variable (_, i, List (_,l)) ->
      Printf.sprintf "%s: [%s]" i (String.concat " " (List.map value l))
    | Variable (_, i, v) -> String.concat ": " [i; value v]
    | Section (_,s) ->
      Printf.sprintf "%s %s{\n%s\n}"
        s.section_kind
        (match s.section_name with
         | Some s -> escape_string s ^ " "
         | None -> "")
        (String.concat "\n" (List.map item s.section_items))

  let item_order a b = match a,b with
    | Section _, Variable _ -> 1
    | Variable _, Section _ -> -1
    | Variable (_,i,_), Variable (_,j,_) -> String.compare i j
    | Section (_,s), Section (_,t) ->
      let r = String.compare s.section_kind t.section_kind in
      if r <> 0 then r
      else compare s.section_name t.section_name

  let items its =
    let its = List.sort item_order its in
    String.concat "\n" (List.map item its) ^ "\n"

  let opamfile f = items f.file_contents
end
