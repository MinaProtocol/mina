(* precomputed_block.ml *)

open Core
open Async

(* Precomputed_block.t type has changed from mainnet, too hard to recreate old type
   get what we need by traversing JSON
*)

let make_target ~state_hash ~height =
  sprintf "mainnet-%Ld-%s.json" height state_hash

(* no precomputed genesis block at height 1 *)
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

let fetch_batch ~height ~num_blocks =
  let batch_args = make_batch_args ~height ~num_blocks in
  let block_uris =
    List.map batch_args ~f:(fun arg ->
        sprintf "gs://mina_network_block_data/%s" arg )
  in
  match%map
    Process.run ~prog:"gsutil" ~args:([ "-m"; "cp" ] @ block_uris @ [ "." ]) ()
  with
  | Ok _ ->
      ()
  | Error err ->
      failwithf
        "Could not download batch of precomputed blocks at height %Ld, error: \
         %s"
        height (Error.to_string_hum err) ()

let block_re = Str.regexp "mainnet-[0-9]+-.+\\.json"

let delete_fetched () : unit Deferred.t =
  let%bind files = Sys.readdir "." in
  let block_files =
    Array.filter files ~f:(fun file -> Str.string_match block_re file 0)
  in
  let args = Array.to_list block_files in
  match%map Process.run ~prog:"rm" ~args () with
  | Ok _ ->
      ()
  | Error err ->
      failwithf "Could not delete fetched precomputed blocks, error %s"
        (Error.to_string_hum err) ()

let get_json_item filter ~state_hash ~height =
  let target = make_target ~state_hash ~height in
  match%map Process.run ~prog:"jq" ~args:[ filter; target ] () with
  | Ok s ->
      Yojson.Safe.from_string s
  | Error err ->
      failwithf
        "Could not get JSON item with filter %s for state hash %s, error: %s"
        filter state_hash (Error.to_string_hum err) ()

let consensus_state_item s = sprintf ".protocol_state.body.consensus_state.%s" s

let last_vrf_output = get_json_item (consensus_state_item "last_vrf_output")

let staking_epoch_data =
  get_json_item (consensus_state_item "staking_epoch_data")

let next_epoch_data = get_json_item (consensus_state_item "next_epoch_data")

let min_window_density =
  get_json_item (consensus_state_item "min_window_density")

let subwindow_densities =
  get_json_item (consensus_state_item "sub_window_densities")

let total_currency = get_json_item (consensus_state_item "total_currency")
