type t = A of string [@@unboxed]

let invalid_argf fmt = Printf.ksprintf invalid_arg fmt

let is_valid_dune =
  let rec loop s i len =
    i = len ||
    match String.unsafe_get s i with
    | '%' -> after_percent s (i + 1) len
    | '"' | '(' | ')' | ';' | '\000'..'\032' | '\127'..'\255' -> false
    | _ -> loop s (i + 1) len
  and after_percent s i len =
    i = len ||
    match String.unsafe_get s i with
    | '%' -> after_percent s (i + 1) len
    | '"' | '(' | ')' | ';' | '\000'..'\032' | '\127'..'\255' | '{' -> false
    | _ -> loop s (i + 1) len
  in
  fun s ->
    let len = String.length s in
    len > 0 && loop s 0 len

let is_valid_jbuild str =
  let len = String.length str in
  len > 0 &&
  let rec loop ix =
    match str.[ix] with
    | '"' | '(' | ')' | ';' -> true
    | '|' -> ix > 0 && let next = ix - 1 in str.[next] = '#' || loop next
    | '#' -> ix > 0 && let next = ix - 1 in str.[next] = '|' || loop next
    | ' ' | '\t' | '\n' | '\012' | '\r' -> true
    | _ -> ix > 0 && loop (ix - 1)
  in
  not (loop (len - 1))

let of_string s = A s
let to_string (A s) = s

let is_valid (A t) = function
  | Syntax.Jbuild -> is_valid_jbuild t
  | Dune   -> is_valid_dune t

let print ((A s) as t) syntax =
  if is_valid t syntax then
    s
  else
    match syntax with
    | Jbuild -> invalid_argf "atom '%s' cannot be printed in jbuild syntax" s
    | Dune -> invalid_argf "atom '%s' cannot be in dune syntax" s

let of_int i = of_string (string_of_int i)
let of_float x = of_string (string_of_float x)
let of_bool x = of_string (string_of_bool x)
let of_digest d = of_string (Digest.to_hex d)
let of_int64 i = of_string (Int64.to_string i)
