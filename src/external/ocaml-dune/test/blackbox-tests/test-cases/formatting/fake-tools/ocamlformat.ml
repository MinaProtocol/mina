let process args ~output =
  let oc = open_out output in
  Printf.fprintf oc "Sys.argv: %s\n" (String.concat " " (Array.to_list args));
  Printf.fprintf oc "ocamlformat output\n";
  close_out oc

let () =
  match Sys.argv with
  | [| _ ; _; _; "--name"; _; "-o"; output|] -> process Sys.argv ~output
  | _ -> assert false
