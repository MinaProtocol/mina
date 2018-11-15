open! Stdune
open! Import

let parse_file path_opt =
  let fname, contents =
    match path_opt with
    | Some path ->
      Io.with_file_in path ~f:(fun ic ->
        let contents = Io.read_all ic in
        (Path.to_string path, contents)
      )
    | None ->
      let lines = Io.input_lines stdin in
      let contents = String.concat ~sep:"\n" lines in
      ("<stdin>", contents)
  in
  Dune_lang.parse_string
    ~fname
    ~mode:Dune_lang.Parser.Mode.Many
    contents

let can_be_displayed_inline =
  List.for_all ~f:(function
    | Dune_lang.Atom _
    | Dune_lang.Quoted_string _
    | Dune_lang.Template _
    | Dune_lang.List [_]
      ->
      true
    | Dune_lang.List _
      ->
      false
  )

let pp_indent fmt indent =
  Format.pp_print_string fmt @@ String.make indent ' '

let print_inline_list fmt indent sexps =
  Format.fprintf fmt "%a(" pp_indent indent;
  let first = ref true in
  List.iter sexps ~f:(fun sexp ->
    if !first then
      first := false
    else
      Format.pp_print_string fmt " ";
    Dune_lang.pp Dune_lang.Dune fmt sexp
  );
  Format.pp_print_string fmt ")"

let rec pp_sexp indent fmt =
  function
    ( Dune_lang.Atom _
    | Dune_lang.Quoted_string _
    | Dune_lang.Template _
    ) as sexp
    ->
    Format.fprintf fmt "%a%a"
      pp_indent indent
      (Dune_lang.pp Dune_lang.Dune) sexp
  | Dune_lang.List sexps
    ->
    if can_be_displayed_inline sexps then
      print_inline_list fmt indent sexps
    else
      pp_sexp_list indent fmt sexps

and pp_sexp_list indent fmt sexps =
    begin
      Format.fprintf fmt "%a(" pp_indent indent;
      let first = ref true in
      List.iter sexps ~f:(fun sexp ->
        let indent =
          if !first then
            begin
              first := false;
              0
            end
          else
            indent + 1
        in
        pp_sexp
          indent
          fmt
          sexp;
        Format.pp_print_string fmt "\n";
      );
      Format.fprintf fmt "%a)" pp_indent indent;
    end

let pp_top_sexp fmt sexp =
  Format.fprintf fmt "%a\n" (pp_sexp 0) sexp

let pp_top_sexps fmt sexps =
  let first = ref true in
  List.iter sexps ~f:(fun sexp ->
    if !first then
      first := false
    else
      Format.pp_print_string fmt "\n";
    pp_top_sexp fmt (Dune_lang.Ast.remove_locs sexp);
  )

let with_output path_opt k =
  match path_opt with
  | None ->
    k Format.std_formatter
  | Some path ->
    Io.with_file_out ~binary:true path ~f:(fun oc ->
      k @@ Format.formatter_of_out_channel oc
    )

let format_file ~input ~output =
  match parse_file input with
  | exception Dune_lang.Parse_error e ->
    Printf.printf
      "Parse error: %s\n"
      (Dune_lang.Parse_error.message e)
  | sexps ->
    with_output output (fun fmt ->
      pp_top_sexps fmt sexps;
      Format.pp_print_flush fmt ()
    )
