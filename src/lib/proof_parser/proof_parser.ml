let read_whole_file filename =
  (* open_in_bin works correctly on Unix and Windows *)
  let ch = open_in_bin filename in
  let s = really_input_string ch (in_channel_length ch) in
  close_in ch ; s

let proof = read_whole_file "../../../../proof.txt"

let decoded_proof = Mina_block.Precomputed.Proof.of_bin_string proof

let proof_json = Mina_base.Proof.Stable.Latest.to_yojson decoded_proof

let proof_string = Yojson.Safe.to_string proof_json

let () = print_endline proof_string
