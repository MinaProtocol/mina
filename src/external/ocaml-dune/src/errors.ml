open! Stdune

exception Already_reported

let max_lines_to_print_in_full = 10

let context_lines = 2

let err_buf = Buffer.create 128
let err_ppf = Format.formatter_of_buffer err_buf
let kerrf fmt ~f =
  Format.kfprintf
    (fun ppf ->
       Format.pp_print_flush ppf ();
       let s = Buffer.contents err_buf in
       Buffer.clear err_buf;
       f s)
    err_ppf fmt

let die fmt =
  kerrf fmt ~f:(fun s -> raise (Exn.Fatal_error s))

let exnf t fmt =
  Format.pp_open_box err_ppf 0;
  Format.pp_print_as err_ppf 7 ""; (* "Error: " *)
  kerrf (fmt^^ "@]") ~f:(fun s -> Exn.Loc_error (t, s))

let fail t fmt =
  Format.pp_print_as err_ppf 7 ""; (* "Error: " *)
  kerrf fmt ~f:(fun s ->
    raise (Exn.Loc_error (t, s)))

let fail_lex lb fmt =
  fail (Loc.of_lexbuf lb) fmt

let fail_opt t fmt =
  match t with
  | None -> die fmt
  | Some t -> fail t fmt

let file_line path n =
  Io.with_file_in ~binary:false path
    ~f:(fun ic ->
      for _ = 1 to n - 1 do
        ignore (input_line ic)
      done;
      input_line ic
    )

let file_lines path ~start ~stop =
  Io.with_file_in ~binary:true path
    ~f:(fun ic ->
      let rec aux acc lnum =
        if lnum > stop then
          List.rev acc
        else if lnum < start then
          (ignore (input_line ic);
           aux acc (lnum + 1))
        else
          let line = input_line ic in
          aux ((string_of_int lnum, line) :: acc) (lnum + 1)
      in
      aux [] 1
    )

let pp_line padding_width pp (lnum, l) =
  Format.fprintf pp "%*s | %s\n" padding_width lnum l

let print ppf loc =
  let { Loc.start; stop } = loc in
  let start_c = start.pos_cnum - start.pos_bol in
  let stop_c  = stop.pos_cnum  - start.pos_bol in
  let num_lines = stop.pos_lnum - start.pos_lnum in
  let pp_file_excerpt pp () =
    let whole_file = start_c = 0 && stop_c = 0 in
    if not whole_file then
      let path = Path.of_string start.pos_fname in
      if Path.exists path then
        let line_num = start.pos_lnum in
        let line_num_str = string_of_int line_num in
        let padding_width = String.length line_num_str in
        let line = file_line path line_num in
        if stop_c <= String.length line then
          let len = stop_c - start_c in
          Format.fprintf pp "%a%*s\n"
            (pp_line padding_width) (line_num_str, line)
            (stop_c + padding_width + 3)
            (String.make len '^')
        else
          let get_padding lines =
            let (lnum, _) = Option.value_exn (List.last lines) in
            String.length lnum
          in
          let print_ellipsis padding_width =
            (* We add 2 to the width of max line to account for
               the extra space and the `|` character at the end
               of a line number *)
            let line = String.make (padding_width + 2) '.' in
            Format.fprintf pp "%s\n" line
          in
          let print_lines lines padding_width =
            List.iter ~f:(fun (lnum, l) ->
              pp_line padding_width pp (lnum, l)) lines;
          in
          if num_lines <= max_lines_to_print_in_full then
            let lines = file_lines path ~start:start.pos_lnum ~stop:stop.pos_lnum in
            print_lines lines (get_padding lines)
          else
            (* We need to send the padding width from the last four lines
               so the two blocks of lines align if they have different number
               of digits in their line numbers *)
            let first_shown_lines = file_lines path ~start:(start.pos_lnum)
                               ~stop:(start.pos_lnum + context_lines) in
            let last_shown_lines = file_lines path ~start:(stop.pos_lnum - context_lines)
                              ~stop:(stop.pos_lnum) in
            let padding_width = get_padding last_shown_lines in
            (print_lines first_shown_lines padding_width;
             print_ellipsis padding_width;
             print_lines last_shown_lines padding_width)
  in
  Format.fprintf ppf
    "@{<loc>File \"%s\", line %d, characters %d-%d:@}@\n%a"
    start.pos_fname start.pos_lnum start_c stop_c
    pp_file_excerpt ()

(* This is ugly *)
let printer = ref (Printf.eprintf "%s%!")
let print_to_console s = !printer s

let warn t fmt =
  kerrf ~f:print_to_console
    ("%a@{<warning>Warning@}: " ^^ fmt ^^ "@.") print t
