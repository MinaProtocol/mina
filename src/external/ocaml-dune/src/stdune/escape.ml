module String = StringLabels

type quote =
  | Needs_quoting_with_length of int
  | No_quoting

let quote_length s =
  let n = ref 0 in
  let len = String.length s in
  let needs_quoting = ref false in
  for i = 0 to len - 1 do
    n := !n + (match String.unsafe_get s i with
      | '\"' | '\\' | '\n' | '\t' | '\r' | '\b' ->
        needs_quoting := true;
        2
      | ' ' ->
        needs_quoting := true;
        1
      | '!' .. '~' -> 1
      | _ ->
        needs_quoting := true;
        4)
  done;
  if !needs_quoting then
    Needs_quoting_with_length len
  else (
    assert (len = !n);
    No_quoting
  )

let escape_to s ~dst:s' ~ofs =
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

(* Surround [s] with quotes, escaping it if necessary. *)
let quote_if_needed s =
  let len = String.length s in
  match quote_length s with
  | No_quoting ->
    s
  | Needs_quoting_with_length n ->
    let s' = Bytes.create (n + 2) in
    Bytes.unsafe_set s' 0 '"';
    if len = 0 || n > len then
      escape_to s ~dst:s' ~ofs:1
    else
      Bytes.blit_string ~src:s ~src_pos:0 ~dst:s' ~dst_pos:1 ~len;
    Bytes.unsafe_set s' (n + 1) '"';
    Bytes.unsafe_to_string s'
