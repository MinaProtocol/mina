{}
rule extract acc = parse
  | "BEGIN-" (['0' - '9']+ as i) "-"
      { read acc (int_of_string i) (Buffer.create 8) lexbuf }
  | _ { extract acc lexbuf }
  | eof { List.rev acc }
and read acc i b = parse
  | "-END" { extract ((i, Buffer.contents b) :: acc) lexbuf }
  | _ as c { Buffer.add_char b c; read acc i b lexbuf }
  | eof { failwith "Unterminated BEGIN-" }
{}
