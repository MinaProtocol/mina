(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

open Result

(* Manpages *)

type block =
  [ `S of string | `P of string | `Pre of string | `I of string * string
  | `Noblank | `Blocks of block list ]

type title = string * int * string * string * string

type t = title * block list

type xref =
  [ `Main | `Cmd of string | `Tool of string | `Page of string * int ]

(* Standard sections *)

let s_name = "NAME"
let s_synopsis = "SYNOPSIS"
let s_description = "DESCRIPTION"
let s_commands = "COMMANDS"
let s_arguments = "ARGUMENTS"
let s_options = "OPTIONS"
let s_common_options = "COMMON OPTIONS"
let s_exit_status = "EXIT STATUS"
let s_exit_status_intro =
  `P "$(tname) exits with the following status:"

let s_environment = "ENVIRONMENT"
let s_environment_intro =
  `P "These environment variables affect the execution of $(tname):"

let s_files = "FILES"
let s_examples = "EXAMPLES"
let s_bugs = "BUGS"
let s_authors = "AUTHORS"
let s_see_also = "SEE ALSO"

(* Section order *)

let s_created = ""
let order =
  [| s_name; s_synopsis; s_description; s_created; s_commands;
     s_arguments; s_options; s_common_options; s_exit_status;
     s_environment; s_files; s_examples; s_bugs; s_authors; s_see_also; |]

let order_synopsis = 1
let order_created = 3

let section_of_order i = order.(i)
let section_to_order ~on_unknown s =
  let max = Array.length order - 1 in
  let rec loop i = match i > max with
  | true -> on_unknown
  | false -> if order.(i) = s then i else loop (i + 1)
  in
  loop 0

(* Section maps

   Section maps, maps section names to their section order and reversed
   content blocks (content is not reversed in `Block blocks). The sections
   are listed in reversed order. Unknown sections get the order of the last
   known section. *)

type smap = (string * (int * block list)) list

let smap_of_blocks bs = (* N.B. this flattens `Blocks, not t.r. *)
  let rec loop s s_o rbs smap = function
  | [] -> s, s_o, rbs, smap
  | `S new_sec :: bs ->
      let new_o = section_to_order ~on_unknown:s_o new_sec in
      loop new_sec new_o [] ((s, (s_o, rbs)):: smap) bs
  | `Blocks blist :: bs ->
      let s, s_o, rbs, rmap = loop s s_o rbs smap blist (* not t.r. *) in
      loop s s_o rbs rmap bs
  | (`P _ | `Pre _ | `I _ | `Noblank as c) :: bs ->
      loop s s_o (c :: rbs) smap bs
  in
  let first, (bs : block list) = match bs with
  | `S s :: bs -> s, bs
  | `Blocks (`S s :: blist) :: bs -> s, (`Blocks blist) :: bs
  | _ -> "", bs
  in
  let first_o = section_to_order ~on_unknown:order_synopsis first in
  let s, s_o, rc, smap = loop first first_o [] [] bs in
  (s, (s_o, rc)) :: smap

let smap_to_blocks smap = (* N.B. this leaves `Blocks content untouched. *)
  let rec loop acc smap s = function
  | b :: rbs -> loop (b :: acc) smap s rbs
  | [] ->
      let acc =  if s = "" then acc else `S s :: acc in
      match smap with
      | (s, (_, rbs)) :: smap -> loop acc smap s rbs
      | [] -> acc
  in
  match smap with
  | [] -> []
  | (s, (_, rbs)) :: smap -> loop [] smap s rbs

let smap_has_section smap ~sec = List.exists (fun (s, _) -> sec = s) smap
let smap_append_block smap ~sec b =
  let o = section_to_order ~on_unknown:order_created sec in
  let try_insert =
    let rec loop max_lt_o left = function
    | (s', (o, rbs)) :: right when s' = sec ->
        Ok (List.rev_append ((sec, (o, b :: rbs)) :: left) right)
    | (_, (o', _) as s) :: right ->
        let max_lt_o = if o' < o then max o' max_lt_o else max_lt_o in
        loop max_lt_o (s :: left) right
    | [] ->
        if max_lt_o <> -1 then Error max_lt_o else
        Ok (List.rev ((sec, (o, [b])) :: left))
    in
    loop (-1) [] smap
  in
  match try_insert with
  | Ok smap -> smap
  | Error insert_before ->
      let rec loop left = function
      | (s', (o', _)) :: _ as right when o' = insert_before ->
          List.rev_append ((sec, (o, [b])) :: left) right
      | s :: ss -> loop (s :: left) ss
      | [] -> assert false
      in
      loop [] smap

(* Formatting tools *)

let strf = Printf.sprintf
let pf = Format.fprintf
let pp_str = Format.pp_print_string
let pp_char = Format.pp_print_char
let pp_indent ppf c = for i = 1 to c do pp_char ppf ' ' done
let pp_lines = Cmdliner_base.pp_lines
let pp_tokens = Cmdliner_base.pp_tokens

(* Cmdliner markup handling *)

let err e fmt = pf e ("cmdliner error: " ^^ fmt ^^ "@.")
let err_unescaped ~errs c s = err errs "unescaped %C in %S" c s
let err_malformed ~errs s = err errs "Malformed $(...) in %S" s
let err_unclosed ~errs s = err errs "Unclosed $(...) in %S" s
let err_undef ~errs id s = err errs "Undefined variable $(%s) in %S" id s
let err_illegal_esc ~errs c s = err errs "Illegal escape char %C in %S" c s
let err_markup ~errs dir s =
  err errs "Unknown cmdliner markup $(%c,...) in %S" dir s

let is_markup_dir = function 'i' | 'b' -> true | _ -> false
let is_markup_esc = function '$' | '\\' | '(' | ')' -> true | _ -> false
let markup_need_esc = function '\\' | '$' -> true | _ -> false
let markup_text_need_esc = function '\\' | '$' | ')' -> true | _ -> false

let escape s = (* escapes [s] from doc language. *)
  let max_i = String.length s - 1 in
  let rec escaped_len i l =
    if i > max_i then l else
    if markup_text_need_esc s.[i] then escaped_len (i + 1) (l + 2) else
    escaped_len (i + 1) (l + 1)
  in
  let escaped_len = escaped_len 0 0 in
  if escaped_len = String.length s then s else
  let b = Bytes.create escaped_len in
  let rec loop i k =
    if i > max_i then Bytes.unsafe_to_string b else
    let c = String.unsafe_get s i in
    if not (markup_text_need_esc c)
    then (Bytes.unsafe_set b k c; loop (i + 1) (k + 1))
    else (Bytes.unsafe_set b k '\\'; Bytes.unsafe_set b (k + 1) c;
          loop (i + 1) (k + 2))
  in
  loop 0 0

let subst_vars ~errs ~subst b s =
  let max_i = String.length s - 1 in
  let flush start stop = match start > max_i with
  | true -> ()
  | false -> Buffer.add_substring b s start (stop - start + 1)
  in
  let skip_escape k start i =
    if i > max_i then err_unescaped ~errs '\\' s else k start (i + 1)
  in
  let rec skip_markup k start i =
    if i > max_i then (err_unclosed ~errs s; k start i) else
    match s.[i] with
    | '\\' -> skip_escape (skip_markup k) start (i + 1)
    | ')' -> k start (i + 1)
    | c -> skip_markup k start (i + 1)
  in
  let rec add_subst start i =
    if i > max_i then (err_unclosed ~errs s; loop start i) else
    if s.[i] <> ')' then add_subst start (i + 1) else
    let id = String.sub s start (i - start) in
    let next = i + 1 in
    begin match subst id with
    | None -> err_undef ~errs id s; Buffer.add_string b "undefined";
    | Some v -> Buffer.add_string b v
    end;
    loop next next
  and loop start i =
    if i > max_i then flush start max_i else
    let next = i + 1 in
    match s.[i] with
    | '\\' -> skip_escape loop start next
    | '$' ->
        if next > max_i then err_unescaped ~errs '$' s else
        begin match s.[next] with
        | '(' ->
            let min = next + 2 in
            if min > max_i then (err_unclosed ~errs s; loop start next) else
            begin match s.[min] with
            | ',' -> skip_markup loop start (min + 1)
            | _ ->
                let start_id = next + 1 in
                flush start (i - 1); add_subst start_id start_id
            end
        | _ -> err_unescaped ~errs '$' s; loop start next
        end;
    | c -> loop start next
  in
  (Buffer.clear b; loop 0 0; Buffer.contents b)

let add_markup_esc ~errs k b s start next target_need_escape target_escape =
  let max_i = String.length s - 1 in
  if next > max_i then err_unescaped ~errs '\\' s else
  match s.[next] with
  | c when not (is_markup_esc s.[next]) ->
      err_illegal_esc ~errs c s;
      k (next + 1) (next + 1)
  | c ->
      (if target_need_escape c then target_escape b c else Buffer.add_char b c);
      k (next + 1) (next + 1)

let add_markup_text ~errs k b s start target_need_escape target_escape =
  let max_i = String.length s - 1 in
  let flush start stop = match start > max_i with
  | true -> ()
  | false -> Buffer.add_substring b s start (stop - start + 1)
  in
  let rec loop start i =
    if i > max_i then (err_unclosed ~errs s; flush start max_i) else
    let next = i + 1 in
    match s.[i] with
    | '\\' -> (* unescape *)
        flush start (i - 1);
        add_markup_esc ~errs loop b s start next
          target_need_escape target_escape
    | ')' -> flush start (i - 1); k next next
    | c when markup_text_need_esc c ->
        err_unescaped ~errs c s; flush start (i - 1); loop next next
    | c when target_need_escape c ->
        flush start (i - 1); target_escape b c; loop next next
    | c -> loop start next
  in
  loop start start

(* Plain text output *)

let markup_to_plain ~errs b s =
  let max_i = String.length s - 1 in
  let flush start stop = match start > max_i with
  | true -> ()
  | false -> Buffer.add_substring b s start (stop - start + 1)
  in
  let need_escape _ = false in
  let escape _ _ = assert false in
  let rec loop start i =
    if i > max_i then flush start max_i else
    let next = i + 1 in
    match s.[i] with
    | '\\' ->
        flush start (i - 1);
        add_markup_esc ~errs loop b s start next need_escape escape
    | '$' ->
        if next > max_i then err_unescaped ~errs '$' s else
        begin match s.[next] with
        | '(' ->
            let min = next + 2 in
            if min > max_i then (err_unclosed ~errs s; loop start next) else
            begin match s.[min] with
            | ',' ->
                let markup = s.[min - 1] in
                if not (is_markup_dir markup)
                then (err_markup ~errs markup s; loop start next) else
                let start_data = min + 1 in
                (flush start (i - 1);
                 add_markup_text ~errs loop b s start_data need_escape escape)
            | _ ->
                err_malformed ~errs s; loop start next
            end
        | _ -> err_unescaped ~errs '$' s; loop start next
        end
    | c when markup_need_esc c ->
        err_unescaped ~errs c s; flush start (i - 1); loop next next
    | c -> loop start next
  in
  (Buffer.clear b; loop 0 0; Buffer.contents b)

let doc_to_plain ~errs ~subst b s =
  markup_to_plain ~errs b (subst_vars ~errs ~subst b s)

let p_indent = 7                                  (* paragraph indentation. *)
let l_indent = 4                                      (* label indentation. *)

let pp_plain_blocks ~errs subst ppf ts =
  let b = Buffer.create 1024 in
  let markup t = doc_to_plain ~errs b ~subst t in
  let pp_tokens ppf t = pp_tokens ~spaces:true ppf t in
  let rec loop = function
  | [] -> ()
  | t :: ts ->
      begin match t with
      | `Noblank -> ()
      | `Blocks bs -> loop bs (* not T.R. *)
      | `P s -> pf ppf "%a@[%a@]@," pp_indent p_indent pp_tokens (markup s)
      | `S s -> pf ppf "@[%a@]" pp_tokens (markup s)
      | `Pre s -> pf ppf "%a@[%a@]@," pp_indent p_indent pp_lines (markup s)
      | `I (label, s) ->
          let label = markup label in
          let s = markup s in
          pf ppf "@[%a@[%a@]" pp_indent p_indent pp_tokens label;
          if s = "" then pf ppf "@]@," else
          let ll = String.length label in
          begin match ll < l_indent with
          | true ->
              pf ppf "%a@[%a@]@]" pp_indent (l_indent - ll) pp_tokens s
          | false ->
              pf ppf "@\n%a@[%a@]@]"
                pp_indent (p_indent + l_indent) pp_tokens s
          end;
          match ts with `I _ :: _ -> pf ppf "@," | _ -> ()
      end;
      begin match ts with
      | `Noblank :: ts -> loop ts
      | ts -> Format.pp_print_cut ppf (); loop ts
      end
  in
  loop ts

let pp_plain_page ~errs subst ppf (_, text) =
  pf ppf "@[<v>%a@]" (pp_plain_blocks ~errs subst) text

(* Groff output *)

let markup_to_groff ~errs b s =
  let max_i = String.length s - 1 in
  let flush start stop = match start > max_i with
  | true -> ()
  | false -> Buffer.add_substring b s start (stop - start + 1)
  in
  let need_escape = function '.' | '\'' | '-' | '\\' -> true | _ -> false in
  let escape b c = Printf.bprintf b "\\N'%d'" (Char.code c) in
  let rec end_text start i = Buffer.add_string b "\\fR"; loop start i
  and loop start i =
    if i > max_i then flush start max_i else
    let next = i + 1 in
    match s.[i] with
    | '\\' ->
        flush start (i - 1);
        add_markup_esc ~errs loop b s start next need_escape escape
    | '$' ->
        if next > max_i then err_unescaped ~errs '$' s else
        begin match s.[next] with
        | '(' ->
            let min = next + 2 in
            if min > max_i then (err_unclosed ~errs s; loop start next) else
            begin match s.[min] with
            | ','  ->
                let start_data = min + 1 in
                flush start (i - 1);
                begin match s.[min - 1] with
                | 'i' -> Buffer.add_string b "\\fI"
                | 'b' -> Buffer.add_string b "\\fB"
                | markup -> err_markup ~errs markup s
                end;
                add_markup_text ~errs end_text b s start_data need_escape escape
            | _ -> err_malformed ~errs s; loop start next
            end
        | _ -> err_unescaped ~errs '$' s; flush start (i - 1); loop next next
        end
    | c when markup_need_esc c ->
        err_unescaped ~errs c s; flush start (i - 1); loop next next
    | c when need_escape c ->
        flush start (i - 1); escape b c; loop next next
    | c -> loop start next
  in
  (Buffer.clear b; loop 0 0; Buffer.contents b)

let doc_to_groff ~errs ~subst b s =
  markup_to_groff ~errs b (subst_vars ~errs ~subst b s)

let pp_groff_blocks ~errs subst ppf text =
  let buf = Buffer.create 1024 in
  let markup t = doc_to_groff ~errs ~subst buf t in
  let pp_tokens ppf t = pp_tokens ~spaces:false ppf t in
  let rec pp_block = function
  | `Blocks bs -> List.iter pp_block bs (* not T.R. *)
  | `P s -> pf ppf "@\n.P@\n%a" pp_tokens (markup s)
  | `Pre s -> pf ppf "@\n.P@\n.nf@\n%a@\n.fi" pp_lines (markup s)
  | `S s -> pf ppf "@\n.SH %a" pp_tokens (markup s)
  | `Noblank -> pf ppf "@\n.sp -1"
  | `I (l, s) ->
      pf ppf "@\n.TP 4@\n%a@\n%a" pp_tokens (markup l) pp_tokens (markup s)
  in
  List.iter pp_block text

let pp_groff_page ~errs subst ppf ((n, s, a1, a2, a3), t) =
  pf ppf ".\\\" Pipe this output to groff -Tutf8 | less@\n\
          .\\\"@\n\
          .mso an.tmac@\n\
          .TH \"%s\" %d \"%s\" \"%s\" \"%s\"@\n\
          .\\\" Disable hyphenation and ragged-right@\n\
          .nh@\n\
          .ad l\
          %a@?"
    n s a1 a2 a3 (pp_groff_blocks ~errs subst) t

(* Printing to a pager *)

let pp_to_temp_file pp_v v =
  try
    let exec = Filename.basename Sys.argv.(0) in
    let file, oc = Filename.open_temp_file exec "out" in
    let ppf = Format.formatter_of_out_channel oc in
    pp_v ppf v; Format.pp_print_flush ppf (); close_out oc;
    at_exit (fun () -> try Sys.remove file with Sys_error e -> ());
    Some file
  with Sys_error _ -> None

let find_cmd cmds =
  let test, null = match Sys.os_type with
  | "Win32" -> "where", " NUL"
  | _ -> "type", "/dev/null"
  in
  let cmd c = Sys.command (strf "%s %s 1>%s 2>%s" test c null null) = 0 in
  try Some (List.find cmd cmds) with Not_found -> None

let pp_to_pager print ppf v =
  let pager =
    let cmds = ["less"; "more"] in
    let cmds = try (Sys.getenv "PAGER") :: cmds with Not_found -> cmds in
    let cmds = try (Sys.getenv "MANPAGER") :: cmds with Not_found -> cmds in
    find_cmd cmds
  in
  match pager with
  | None -> print `Plain ppf v
  | Some pager ->
      let cmd = match (find_cmd ["groff"; "nroff"]) with
      | None ->
          begin match pp_to_temp_file (print `Plain) v with
          | None -> None
          | Some f -> Some (strf "%s < %s" pager f)
          end
      | Some c ->
          begin match pp_to_temp_file (print `Groff) v with
          | None -> None
          | Some f ->
              (* TODO use -Tutf8, but annoyingly maps U+002D to U+2212. *)
              let xroff = if c = "groff" then c ^ " -Tascii -P-c" else c in
              Some (strf "%s < %s | %s" xroff f pager)
          end
      in
      match cmd with
      | None -> print `Plain ppf v
      | Some cmd -> if (Sys.command cmd) <> 0 then print `Plain ppf v

(* Output *)

type format = [ `Auto | `Pager | `Plain | `Groff ]

let rec print
    ?(errs = Format.err_formatter)
    ?(subst = fun x -> None) fmt ppf page =
  match fmt with
  | `Pager -> pp_to_pager (print ~errs ~subst) ppf page
  | `Plain -> pp_plain_page ~errs subst ppf page
  | `Groff -> pp_groff_page ~errs subst ppf page
  | `Auto ->
      match try (Some (Sys.getenv "TERM")) with Not_found -> None with
      | None | Some "dumb" -> print ~errs ~subst `Plain ppf page
      | Some _ -> print ~errs ~subst `Pager ppf page

(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
