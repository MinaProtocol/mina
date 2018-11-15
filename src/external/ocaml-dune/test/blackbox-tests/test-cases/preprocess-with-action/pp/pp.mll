rule main = parse
  | eof { () }
  | "_STRING_" { Printf.printf "%S" "Hello, world!"; main lexbuf }
  | _ as c { print_char c; main lexbuf }

{
  let () =
    set_binary_mode_out stdout true;
    main (Lexing.from_channel (open_in_bin Sys.argv.(1)))
}
