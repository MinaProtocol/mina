open Core
open Async

module Color = struct
  type t = Black | Red | Green | Yellow | Blue | Magenta | Cyan | White

  let to_int = function
    | Black -> 0
    | Red -> 1
    | Green -> 2
    | Yellow -> 3
    | Blue -> 4
    | Magenta -> 5
    | Cyan -> 6
    | White -> 7

  let color color text = sprintf "\027[38;5;%dm%s\027[0m" (to_int color) text
end

let color_of_level : Logger.Level.t -> Color.t = function
  | Trace -> Blue
  | Debug -> Green
  | Info -> Cyan
  | Warn -> Yellow
  | Error -> Red
  | Faulty_peer -> Magenta
  | Fatal -> Magenta

let colored_level level =
  Color.color (color_of_level level) (sprintf !"%{sexp:Logger.Level.t}" level)

let pretty_print_message
    {Logger.Message.attributes; path; level; pid; host; time; location; message}
    =
  printf
    !"[%{Time}] %s (%{Pid} on %s): %s\n"
    time (colored_level level) pid host
    (Color.color Green message) ;
  if not (Map.is_empty attributes) then
    printf "    %s\n"
      (Sexp.to_string_hum ~indent:4
         ([%sexp_of: Sexp.t String.Map.t] attributes))

let pos_string lexbuf =
  let open Lexing in
  let pos = lexbuf.lex_curr_p in
  sprintf "%s:%d:%d" pos.pos_fname pos.pos_lnum (pos.pos_cnum - pos.pos_bol + 1)

let parse_filter =
  let parse_with_error lexbuf =
    match Filter_parser.prog Filter_lexer.read lexbuf with
    | None -> Or_error.error_string "none"
    | Some filter -> Ok filter
    | exception Filter_lexer.SyntaxError msg ->
        Or_error.error_string (sprintf "%s: %s\n" (pos_string lexbuf) msg)
    | exception Filter_parser.Error ->
        Or_error.error_string
          (sprintf "%s: syntax error\n" (pos_string lexbuf))
  in
  fun s -> parse_with_error (Lexing.from_string s)

let parse_filter_exn s = Or_error.ok_exn (parse_filter s)

let filter_arg = Command.Arg_type.create parse_filter_exn

let main filter () =
  Pipe.iter_without_pushback
    (Reader.lines (Lazy.force Reader.stdin))
    ~f:(fun l ->
      try
        (* trying with _exn on purpose, there are other things in this block that throw *)
        let m = Sexp.of_string_conv_exn l Logger.Message.t_of_sexp in
        if Filter.eval filter m then pretty_print_message m
      with _ -> printf !"%s\n" l )

let () =
  Command.async ~summary:"Pretty print logs"
    (let open Command.Let_syntax in
    let%map_open filter =
      flag "c" ~doc:"filter" (optional_with_default Filter.True filter_arg)
    in
    main filter)
  |> Command.run
