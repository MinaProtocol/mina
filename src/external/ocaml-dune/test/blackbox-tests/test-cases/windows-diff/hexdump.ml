let () =
  let ic = open_in_bin Sys.argv.(1) in
  let col = ref 0 in
  try
    while true do
      let x = Char.code (input_char ic) in
      (match !col with
       | 0 -> ()
       | 8 -> print_string "  "
       | _ -> print_char ' ');
      incr col;
      Printf.printf "%02x" x;
      if !col = 16 then begin
        print_newline ();
        col := 0;
      end
    done
  with End_of_file ->
    if !col <> 0 then print_newline ()
