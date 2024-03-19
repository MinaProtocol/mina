(* precomputed_block.ml *)

module Camlp_stream = Stream
open Core
open Async

(* Precomputed_block.t type has changed from mainnet, too hard to recreate old type
   get what we need by traversing JSON
*)

module Id = struct
  (* TODO: is there any good reason for this to be an int64? *)
  (* TODO: consider just making this `Length.t * State_hash.t` *)
  module T = struct
    type t = int64 * string [@@deriving compare, sexp]
  end

  include T
  include Comparable.Make (T)

  let filename ~network (height, state_hash) =
    sprintf "%s-%Ld-%s.json" network height state_hash
end

(* We define a subset of the mainnet precomputed block type here for the fields we need, to avoid the need to port some of the tricky old types *)

type blockchain_state = { snarked_ledger_hash : Mina_base.Ledger_hash.t }

type consensus_state =
  { blockchain_length : Mina_numbers.Length.t
  ; block_creator : Signature_lib.Public_key.Compressed.t
  ; block_stake_winner : Signature_lib.Public_key.Compressed.t
  ; last_vrf_output : string
  ; staking_epoch_data : Mina_base.Epoch_data.t
  ; next_epoch_data : Mina_base.Epoch_data.t
  ; min_window_density : Mina_numbers.Length.t
  ; sub_window_densities : Mina_numbers.Length.t list
  ; total_currency : Currency.Amount.t
  }

type protocol_state_body =
  { blockchain_state : blockchain_state; consensus_state : consensus_state }

type protocol_state = { body : protocol_state_body }

type t = { protocol_state : protocol_state }

let of_block_header header =
  let module Consensus_state = Consensus.Data.Consensus_state in
  let protocol_state = Mina_block.Header.protocol_state header in
  let blockchain_state =
    Mina_state.Protocol_state.blockchain_state protocol_state
  in
  let consensus_state =
    Mina_state.Protocol_state.consensus_state protocol_state
  in
  { protocol_state =
      { body =
          { blockchain_state =
              { snarked_ledger_hash =
                  Mina_state.Blockchain_state.snarked_ledger_hash
                    blockchain_state
              }
          ; consensus_state =
              { blockchain_length =
                  Consensus_state.blockchain_length consensus_state
              ; block_creator = Consensus_state.block_creator consensus_state
              ; block_stake_winner =
                  Consensus_state.block_stake_winner consensus_state
              ; last_vrf_output =
                  Consensus_state.last_vrf_output consensus_state
              ; staking_epoch_data =
                  Consensus_state.staking_epoch_data consensus_state
              ; next_epoch_data =
                  Consensus_state.next_epoch_data consensus_state
              ; min_window_density =
                  Consensus_state.min_window_density consensus_state
              ; sub_window_densities =
                  Consensus_state.sub_window_densities consensus_state
              ; total_currency = Consensus_state.total_currency consensus_state
              }
          }
      }
  }

(* Couldn't get the deriver to generate a valid of_yojson implementation here for some reason, so we hand=write one instead *)
let of_yojson json =
  let open Yojson.Safe.Util in
  let protocol_state_json = member "protocol_state" json in
  let protocol_state_body_json = member "body" protocol_state_json in
  let blockchain_state_json =
    member "blockchain_state" protocol_state_body_json
  in
  let consensus_state_json =
    member "consensus_state" protocol_state_body_json
  in
  let snarked_ledger_hash_json =
    member "snarked_ledger_hash" blockchain_state_json
  in
  let snarked_ledger_hash =
    Result.ok_or_failwith
    @@ Mina_base.Ledger_hash.of_yojson snarked_ledger_hash_json
  in
  let blockchain_length_json =
    member "blockchain_length" consensus_state_json
  in
  let blockchain_length =
    Result.ok_or_failwith
    @@ Mina_numbers.Length.of_yojson blockchain_length_json
  in
  let block_creator_json = member "block_creator" consensus_state_json in
  let block_creator =
    Result.ok_or_failwith
    @@ Signature_lib.Public_key.Compressed.of_yojson block_creator_json
  in
  let block_stake_winner_json =
    member "block_stake_winner" consensus_state_json
  in
  let block_stake_winner =
    Result.ok_or_failwith
    @@ Signature_lib.Public_key.Compressed.of_yojson block_stake_winner_json
  in
  let last_vrf_output_json = member "last_vrf_output" consensus_state_json in
  let last_vrf_output = to_string last_vrf_output_json in
  let staking_epoch_data_json =
    member "staking_epoch_data" consensus_state_json
  in
  let staking_epoch_data =
    Result.ok_or_failwith
    @@ Mina_base.Epoch_data.of_yojson staking_epoch_data_json
  in
  let next_epoch_data_json = member "next_epoch_data" consensus_state_json in
  let next_epoch_data =
    Result.ok_or_failwith @@ Mina_base.Epoch_data.of_yojson next_epoch_data_json
  in
  let min_window_density_json =
    member "min_window_density" consensus_state_json
  in
  let min_window_density =
    Result.ok_or_failwith
    @@ Mina_numbers.Length.of_yojson min_window_density_json
  in
  let sub_window_densities_json =
    member "sub_window_densities" consensus_state_json
  in
  let sub_window_densities =
    Result.ok_or_failwith
    @@ [%of_yojson: Mina_numbers.Length.t list] sub_window_densities_json
  in
  let total_currency_json = member "total_currency" consensus_state_json in
  let total_currency =
    Result.ok_or_failwith @@ Currency.Amount.of_yojson total_currency_json
  in
  { protocol_state =
      { body =
          { blockchain_state = { snarked_ledger_hash }
          ; consensus_state =
              { blockchain_length
              ; block_creator
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

let block_filename_regexp ~network =
  Str.regexp (sprintf "%s-[0-9]+-.+\\.json" network)

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
           else None
         else None )
  |> Id.Set.of_list

let concrete_fetch_batch ~logger ~bucket ~network targets =
  let%bind existing_targets = list_directory ~network in
  [%log info] "Found %d individiaully downloaded precomputed blocks"
    (Set.length existing_targets) ;
  let missing_targets = Set.diff (Id.Set.of_list targets) existing_targets in
  (*
  [%log info] "Determining precomputed block requirements" ;
  let%bind missing_targets =
    let%map existing = list_directory ~network in
    [%log info] "Found %d precomputed blocks" (Set.length existing) ;
    Set.diff (Id.Set.of_list targets) existing
  in
  *)
  let num_missing_targets = Set.length missing_targets in
  [%log info] "Will download %d precomputed blocks (this may take a while)"
    num_missing_targets ;
  let block_uris_to_download =
    List.map (Set.to_list missing_targets) ~f:(fun target ->
        sprintf "gs://%s/%s" bucket (Id.filename ~network target) )
  in
  if List.is_empty block_uris_to_download then
    return Mina_base.State_hash.Map.empty
  else
    let gsutil_input = String.concat ~sep:"\n" block_uris_to_download in
    let gsutil_process =
      Process.run ~prog:"gsutil" ~args:[ "-m"; "cp"; "-I"; "." ]
        ~stdin:gsutil_input ()
    in
    don't_wait_for
      (let rec progress_loop () =
         let%bind existing = list_directory ~network in
         let downloaded_targets =
           Set.length (Set.inter missing_targets existing)
         in
         [%log info] "%d/%d files downloaded (%%%f)" downloaded_targets
           num_missing_targets
           Float.(
             100.0 * of_int downloaded_targets / of_int num_missing_targets) ;
         let%bind () = after (Time.Span.of_sec 10.0) in
         if Deferred.is_determined gsutil_process then Deferred.unit
         else progress_loop ()
       in
       progress_loop () ) ;
    match%bind gsutil_process with
    | Ok _ ->
        [%log info] "Finished downloading precomputed blocks" ;
        (* limit number of open files to avoid exceeding ulimits *)
        let file_throttle =
          Throttle.create ~continue_on_error:false ~max_concurrent_jobs:100
        in
        Deferred.List.map targets ~how:`Parallel ~f:(fun target ->
            let _, state_hash = target in
            let%map contents =
              Throttle.enqueue file_throttle (fun () ->
                  Reader.file_contents (Id.filename ~network target) )
            in
            let block = of_yojson (Yojson.Safe.from_string contents) in
            (Mina_base.State_hash.of_base58_check_exn state_hash, block) )
        >>| Mina_base.State_hash.Map.of_alist_exn
    | Error err ->
        failwithf "Could not download batch of precomputed blocks: %s"
          (Error.to_string_hum err) ()

let delete_fetched ~network : unit Deferred.t =
  let%bind files = Sys.readdir "." in
  let block_files =
    Array.filter files ~f:(fun file ->
        Str.string_match (block_filename_regexp ~network) file 0 )
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
