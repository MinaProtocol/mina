open! Stdune

let quote_length s ~syntax =
  let n = ref 0 in
  let len = String.length s in
  for i = 0 to len - 1 do
    n := !n + (match String.unsafe_get s i with
      | '\"' | '\\' | '\n' | '\t' | '\r' | '\b' -> 2
      | '%' ->
        if syntax = Syntax.Dune && i + 1 < len && s.[i+1] = '{' then 2 else 1
      | ' ' .. '~' -> 1
      | _ -> 4)
  done;
  !n

let escape_to s ~dst:s' ~ofs ~syntax =
  let n = ref ofs in
  let len = String.length s in
  for i = 0 to len - 1 do
    begin match String.unsafe_get s i with
    | ('\"' | '\\') as c ->
      Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n c
    | '\n' ->
      Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 'n'
    | '\t' ->
      Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 't'
    | '\r' ->
      Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 'r'
    | '\b' ->
      Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 'b'
    | '%' when syntax = Syntax.Dune && i + 1 < len && s.[i + 1] = '{' ->
      Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n '%'
    | (' ' .. '~') as c -> Bytes.unsafe_set s' !n c
    | c ->
      let a = Char.code c in
      Bytes.unsafe_set s' !n '\\';
      incr n;
      Bytes.unsafe_set s' !n (Char.unsafe_chr (48 + a / 100));
      incr n;
      Bytes.unsafe_set s' !n (Char.unsafe_chr (48 + (a / 10) mod 10));
      incr n;
      Bytes.unsafe_set s' !n (Char.unsafe_chr (48 + a mod 10));
    end;
    incr n
  done

(* Escape [s] if needed. *)
let escaped s ~syntax =
  let n = quote_length s ~syntax in
  if n = 0 || n > String.length s then
    let s' = Bytes.create n in
    escape_to s ~dst:s' ~ofs:0 ~syntax;
    Bytes.unsafe_to_string s'
  else s

(* Surround [s] with quotes, escaping it if necessary. *)
let quoted s ~syntax =
  let len = String.length s in
  let n = quote_length s ~syntax in
  let s' = Bytes.create (n + 2) in
  Bytes.unsafe_set s' 0 '"';
  if len = 0 || n > len then
    escape_to s ~dst:s' ~ofs:1 ~syntax
  else
    Bytes.blit_string ~src:s ~src_pos:0 ~dst:s' ~dst_pos:1 ~len;
  Bytes.unsafe_set s' (n + 1) '"';
  Bytes.unsafe_to_string s'
