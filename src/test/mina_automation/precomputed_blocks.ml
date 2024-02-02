open Core
open Async

let make_target ~state_hash ~height =
  sprintf "mainnet-%Ld-%s.json" height state_hash

let min_fetchable_height = 2L

let make_batch_args ~height ~num_blocks =
  let start_height = Int64.max min_fetchable_height height in
  let actual_num_blocks =
    if Int64.( < ) height min_fetchable_height then
      Int64.(num_blocks - min_fetchable_height)
    else num_blocks
  in
  List.init (Int64.to_int_exn actual_num_blocks) ~f:(fun n ->
      sprintf "mainnet-%Ld-*.json" Int64.(start_height + Int64.of_int n) )

let fetch_batch ~height ~num_blocks ~bucket ~output_folder =
  let batch_args = make_batch_args ~height ~num_blocks in
  let block_uris =
    List.map batch_args ~f:(fun arg -> sprintf "gs://%s/%s" bucket arg)
  in
  match%map
    Process.run ~prog:"gsutil"
      ~args:([ "-m"; "cp" ] @ block_uris @ [ output_folder ])
      ()
  with
  | Ok _ ->
      ()
  | Error err ->
      failwithf
        "Could not download batch of precomputed blocks at height %Ld, error: \
         %s"
        height (Error.to_string_hum err) ()

let block_re = Str.regexp "mainnet-[0-9]+-.+\\.json"
