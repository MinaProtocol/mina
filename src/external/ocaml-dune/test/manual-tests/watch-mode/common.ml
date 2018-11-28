let env_var = "DUNE_TEST_SOCKET"

let write_file fn x =
  let oc = open_out fn in
  output_string oc x;
  close_out oc

let read_file fn =
  let ic = open_in fn in
  let s = input_line ic in
  close_in ic;
  s
