open Core
open Digestif

let () = 
  let ctx = Digestif.SHA256.init () in
  let input = Bytes.of_char_list (List.init 64 ~f:(fun _ -> Char.of_int_exn 1)) in
  let ctx = Digestif.SHA256.feed_bytes ctx input  in
  Printf.printf "Direct digest ocaml Digestif:\n";
  let () = Array.iter ctx.h ~f:(fun x -> Printf.printf "%lu " x) in
  Printf.printf "\n";
