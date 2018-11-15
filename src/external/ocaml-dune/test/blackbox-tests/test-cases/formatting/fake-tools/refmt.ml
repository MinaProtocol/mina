let process args =
  Printf.printf "Sys.argv: %s\n" (String.concat " " (Array.to_list args));
  Printf.printf "refmt output\n"

let () =
  match Sys.argv with
  | [| _ ; _|] -> process Sys.argv
  | _ -> assert false
