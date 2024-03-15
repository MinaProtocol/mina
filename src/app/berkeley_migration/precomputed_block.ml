(* precomputed_block.ml *)

open Core
open Async

(* Precomputed_block.t type has changed from mainnet, too hard to recreate old type
   get what we need by traversing JSON
*)

module Id = struct
  module T = struct
    type t = int64 * string
    [@@deriving compare, sexp]
  end

  include T
  include Comparable.Make (T)
end

let yojson_debug name of_yojson x =
  Writer.writef (Lazy.force Writer.stdout) "ENTERING %s\n" name ;
  let result = of_yojson x in
  Writer.writef (Lazy.force Writer.stdout) "EXITING %s\n" name ;
  result

(* subset definition of the mainnet precomputed block type, sans old types *)
type blockchain_state = { snarked_ledger_hash : Mina_base.Ledger_hash.t }
[@@deriving yojson]
let blockchain_state_body_of_yojson = yojson_debug "blockchain_state" blockchain_state_of_yojson
type consensus_state =
  { block_creator : Signature_lib.Public_key.Compressed.t
  ; block_stake_winner : Signature_lib.Public_key.Compressed.t
  ; last_vrf_output : string
  ; staking_epoch_data : Mina_base.Epoch_data.t
  ; next_epoch_data : Mina_base.Epoch_data.t
  ; min_window_density : Mina_numbers.Length.t
  ; sub_window_densities : Mina_numbers.Length.t list
  ; total_currency : Currency.Amount.t
  }
[@@deriving of_yojson]
let consensus_state_body_of_yojson = yojson_debug "consensus_state" consensus_state_of_yojson
type protocol_state_body = { blockchain_state : blockchain_state; consensus_state : consensus_state }
[@@deriving of_yojson]
let protocol_state_body_of_yojson = yojson_debug "protocol_state_body" protocol_state_body_of_yojson
type protocol_state = { body : protocol_state_body }
[@@deriving of_yojson]
let protocol_state_of_yojson = yojson_debug "protocol_state" protocol_state_of_yojson
type t = { protocol_state : protocol_state }
[@@deriving of_yojson]
let of_yojson = yojson_debug "t" of_yojson

let of_block_header header =
  let module Consensus_state = Consensus.Data.Consensus_state in
  let protocol_state = Mina_block.Header.protocol_state header in
  let blockchain_state = Mina_state.Protocol_state.blockchain_state protocol_state in
  let consensus_state = Mina_state.Protocol_state.consensus_state protocol_state in
  { protocol_state =
    { body =
      { blockchain_state =
        { snarked_ledger_hash = Mina_state.Blockchain_state.snarked_ledger_hash blockchain_state }
      ; consensus_state =
        { block_creator = Consensus_state.block_creator consensus_state
        ; block_stake_winner = Consensus_state.block_stake_winner consensus_state
        ; last_vrf_output = Consensus_state.last_vrf_output consensus_state
        ; staking_epoch_data = Consensus_state.staking_epoch_data consensus_state
        ; next_epoch_data = Consensus_state.next_epoch_data consensus_state
        ; min_window_density = Consensus_state.min_window_density consensus_state
        ; sub_window_densities = Consensus_state.sub_window_densities consensus_state
        ; total_currency = Consensus_state.total_currency consensus_state
        }
      }
    }
  }

let custom_of_yojson json =
  let open Yojson.Safe.Util in
  let protocol_state_json = member "protocol_state" json in
  let protocol_state_body_json = member "body" protocol_state_json in
  let blockchain_state_json = member "blockchain_state" protocol_state_body_json in
  let consensus_state_json = member "consensus_state" protocol_state_body_json in
  let snarked_ledger_hash_json = member "snarked_ledger_hash" blockchain_state_json in
  let snarked_ledger_hash = Result.ok_or_failwith @@ Mina_base.Ledger_hash.of_yojson snarked_ledger_hash_json in
  let block_creator_json = member "block_creator" consensus_state_json in
  let block_creator = Result.ok_or_failwith @@ Signature_lib.Public_key.Compressed.of_yojson block_creator_json in
  let block_stake_winner_json = member "block_stake_winner" consensus_state_json in
  let block_stake_winner = Result.ok_or_failwith @@ Signature_lib.Public_key.Compressed.of_yojson block_stake_winner_json in
  let last_vrf_output_json = member "last_vrf_output" consensus_state_json in
  let last_vrf_output = to_string last_vrf_output_json in
  let staking_epoch_data_json = member "staking_epoch_data" consensus_state_json in
  let staking_epoch_data = Result.ok_or_failwith @@ Mina_base.Epoch_data.of_yojson staking_epoch_data_json in
  let next_epoch_data_json = member "next_epoch_data" consensus_state_json in
  let next_epoch_data = Result.ok_or_failwith @@ Mina_base.Epoch_data.of_yojson next_epoch_data_json in
  let min_window_density_json = member "min_window_density" consensus_state_json in
  let min_window_density = Result.ok_or_failwith @@ Mina_numbers.Length.of_yojson min_window_density_json in
  let sub_window_densities_json = member "sub_window_densities" consensus_state_json in
  let sub_window_densities = Result.ok_or_failwith @@ [%of_yojson: Mina_numbers.Length.t list] sub_window_densities_json in
  let total_currency_json = member "total_currency" consensus_state_json in
  let total_currency = Result.ok_or_failwith @@ Currency.Amount.of_yojson total_currency_json in
  { protocol_state =
      { body =
          { blockchain_state =
              { snarked_ledger_hash }
          ; consensus_state =
              { block_creator
              ; block_stake_winner
              ; last_vrf_output
              ; staking_epoch_data
              ; next_epoch_data
              ; min_window_density
              ; sub_window_densities
              ; total_currency
              }
          }
      }
  }

let make_target ~network ~state_hash ~height =
  sprintf "%s-%Ld-%s.json" network height state_hash

(* no precomputed genesis block at height 1 *)
let min_fetchable_height = 2L

let make_batch_args ~network ~height ~num_blocks =
  let start_height = Int64.max min_fetchable_height height in
  let actual_num_blocks =
    if Int64.( < ) height min_fetchable_height then
      Int64.(num_blocks - min_fetchable_height)
    else num_blocks
  in
  List.init (Int64.to_int_exn actual_num_blocks) ~f:(fun n ->
      sprintf "%s-%Ld-*.json" network Int64.(start_height + Int64.of_int n) )

let list_directory ~network =
  let regexp = Str.regexp {|^\([^-]+\)-\([^-]+\)-\(3N[^-]+\)\.json$|} in
  let%map filenames = Sys.readdir "." in
  Array.to_list filenames
  |> List.filter_map ~f:(fun filename ->
      if Str.string_match regexp filename 0 then
        let filename_network = Str.matched_group 1 filename in
        if String.equal filename_network network then
          let height = Str.matched_group 2 filename in
          let state_hash = Str.matched_group 3 filename in
          Some (Int64.of_int @@ Int.of_string height, state_hash)
        else
          None
      else
        None)
  |> Id.Set.of_list

let concrete_fetch_batch ~logger ~bucket ~network targets =
  let num_targets = Set.length targets in
  let block_filenames =
    List.map (Set.to_list targets) ~f:(fun (height, state_hash) ->
      (state_hash, sprintf "%s-%Ld-%s.json" network height state_hash))
  in
  let block_uris =
    List.map block_filenames ~f:(fun (_state_hash, filename) ->
      sprintf "gs://%s/%s" bucket filename)
  in
  let gsutil_input = String.concat ~sep:"\n" block_uris in
  let gsutil_process = Process.run ~prog:"gsutil" ~args:([ "-m"; "cp"; "-I"; "." ]) ~stdin:gsutil_input () in
  don't_wait_for (
    let rec progress_loop () =
      let%bind () = after (Time.Span.of_sec 10.0) in
      if Deferred.is_determined gsutil_process then
        Deferred.unit
      else (
        let%bind available_blocks = list_directory ~network in
        let downloaded_targets = Set.length (Set.inter targets available_blocks) in
        [%log info] "%d/%d files downloaded (%%%f)"
          downloaded_targets
          num_targets
          Float.(of_int downloaded_targets / of_int num_targets) ;
        progress_loop ())
    in
    progress_loop () ) ;
  match%bind gsutil_process with
  | Ok _ ->
      Deferred.List.fold block_filenames ~init:Mina_base.State_hash.Map.empty ~f:(fun acc (state_hash, filename) ->
        let%map contents = Reader.file_contents filename in
        let block =
          Yojson.Safe.from_string contents
          |> custom_of_yojson
          (*|> Result.ok_or_failwith*)
        in
        Map.add_exn acc ~key:(Mina_base.State_hash.of_base58_check_exn state_hash) ~data:block)
  | Error err ->
      failwithf
        "Could not download batch of precomputed blocks: %s"
        (Error.to_string_hum err) ()

let fetch_batch ~height ~num_blocks ~bucket ~network =
  let batch_args = make_batch_args ~height ~num_blocks ~network in
  let block_uris =
    List.map batch_args ~f:(fun arg -> sprintf "gs://%s/%s" bucket arg)
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

let block_re ~network = Str.regexp (sprintf "%s-[0-9]+-.+\\.json" network)

let delete_fetched ~network : unit Deferred.t =
  let%bind files = Sys.readdir "." in
  let block_files =
    Array.filter files ~f:(fun file ->
        Str.string_match (block_re ~network) file 0 )
  in
  let args = Array.to_list block_files in
  if List.length args > 0 then
    match%map Process.run ~prog:"rm" ~args () with
    | Ok _ ->
        ()
    | Error err ->
        failwithf "Could not delete fetched precomputed blocks, error %s"
          (Error.to_string_hum err) ()
  else Deferred.unit

let get_json_item filter ~state_hash ~height ~network =
  let target = make_target ~state_hash ~height ~network in
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
