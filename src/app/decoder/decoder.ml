open Coda_base

let () =
  if Array.length Sys.argv < 2 then
    failwith "MISSING ARGUMENT"
  else
    let state_hash_b58 = Sys.argv.(1) in
    State_hash.of_base58_check_exn state_hash_b58
    |> State_hash.to_yojson
    |> Yojson.Safe.to_string
    |> print_endline
