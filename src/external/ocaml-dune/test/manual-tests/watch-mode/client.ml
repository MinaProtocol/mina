open Common

let () =
  let x = read_file "x" in
  let fn = Sys.getenv env_var in
  let fd = Unix.socket PF_UNIX SOCK_STREAM 0 in
  Unix.connect fd (ADDR_UNIX fn);
  let ic = Unix.in_channel_of_descr fd in
  let oc = Unix.out_channel_of_descr fd in
  assert (input_line ic = "go");
  write_file "y" x;
  Printf.fprintf oc "done\n%!"

