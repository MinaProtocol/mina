let print_var k =
  match Sys.getenv k with
  | v -> Printf.printf "%s = %S\n" k v
  | exception Not_found -> Printf.printf "%s is not set\n" k

let () =
  print_var "X";
  print_var "Y"
