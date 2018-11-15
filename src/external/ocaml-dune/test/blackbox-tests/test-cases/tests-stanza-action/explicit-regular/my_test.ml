let show_argument n argument =
  Printf.printf "argv[%d] = %S\n" n argument

let () = Array.iteri show_argument Sys.argv
