include Dune_caml.Filename

(* Return the index of the start of the extension, using the same semantic as
   [Filename.extension] in 4.04 *)
let extension_start =
  (* This is from the win32 implementation, but it is acceptable for
     the usage we make of it in this function and covers all
     platforms. *)
  let is_dir_sep = function
    | '/' | '\\' | ':' -> true
    | _ -> false
  in
  let rec check_at_least_one_non_dot s len candidate i =
    if i < 0 then
      len
    else
      match s.[i] with
      | '.' ->
        check_at_least_one_non_dot s len candidate (i - 1)
      | c ->
        if is_dir_sep c then
          len
        else
          candidate
  in
  let rec search_dot s len i =
    if i <= 0 then
      len
    else
      match s.[i] with
      | '.' -> check_at_least_one_non_dot s len i (i - 1)
      | c   -> if is_dir_sep c then len else search_dot s len (i - 1)
  in
  fun s ->
    let len = String.length s in
    search_dot s len (len - 1)

let split_extension fn =
  let i = extension_start fn in
  String.split_n fn i

let split_extension_after_dot fn =
  let i = extension_start fn + 1 in
  let len = String.length fn in
  if i > len then
    (fn, "")
  else
    String.split_n fn i

let extension fn =
  String.drop fn (extension_start fn)

type program_name_kind =
  | In_path
  | Relative_to_current_dir
  | Absolute

let analyze_program_name fn =
  if not (is_relative fn) then
    Absolute
  else if String.contains fn '/' || (Sys.win32 && String.contains fn '\\') then
    Relative_to_current_dir
  else
    In_path
