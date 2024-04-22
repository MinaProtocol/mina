(* precomputed_block.ml *)

open Core
open Async

(* Precomputed_block.t type has changed from mainnet, too hard to recreate old type
   get what we need by traversing JSON
*)

module Id = struct
  module T = struct
    type t = Mina_numbers.Length.t * Mina_base.State_hash.t
    [@@deriving compare, sexp]
  end

  include T
  include Comparable.Make (T)

  let filename ~network (height, state_hash) =
    sprintf "%s-%s-%s.json" network
      (Mina_numbers.Length.to_string height)
      (Mina_base.State_hash.to_base58_check state_hash)
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

let bar ?data ~total label =
  let open Progress.Line in
  list [ const label; spinner (); bar ?data total; eta total; count_to total ]

let parse_filename filename =
  let open Option.Let_syntax in
  let rest, ext = Filename.split_extension filename in
  let%bind () = match ext with Some "json" -> Some () | _ -> None in
  let%bind rest, state_hash_str = String.rsplit2 rest ~on:'-' in
  let%bind network, height_str = String.rsplit2 rest ~on:'-' in
  let%bind height =
    Option.try_with (fun () ->
        Mina_numbers.Length.of_int @@ Int.of_string height_str )
  in
  let%map state_hash =
    Or_error.ok (Mina_base.State_hash.of_base58_check state_hash_str)
  in
  (network, height, state_hash)

let list_directory ~network ~path =
  let%map filenames = Sys.readdir path in
  Array.to_list filenames
  |> List.filter_map ~f:(fun filename ->
         let%bind.Option filename_network, height, state_hash =
           parse_filename filename
         in
         if String.equal filename_network network then Some (height, state_hash)
         else None )
  |> Id.Set.of_list

let concrete_fetch_batch ~logger ~bucket ~network targets ~local_path =
  let%bind existing_targets = list_directory ~network ~path:local_path in
  [%log info] "Found %d individually downloaded precomputed blocks"
    (Set.length existing_targets) ;
  let missing_targets = Set.diff (Id.Set.of_list targets) existing_targets in
  let num_missing_targets = Set.length missing_targets in
  [%log info] "Will download %d precomputed blocks (this may take a while)"
    num_missing_targets ;
  let block_uris_to_download =
    List.map (Set.to_list missing_targets) ~f:(fun target ->
        sprintf "gs://%s/%s" bucket (Id.filename ~network target) )
  in
  let%bind () =
    if List.is_empty block_uris_to_download then Deferred.unit
    else
      let gsutil_input = String.concat ~sep:"\n" block_uris_to_download in
      let gsutil_process =
        Process.run ~prog:"gsutil"
          ~args:[ "-m"; "cp"; "-I"; local_path ]
          ~stdin:gsutil_input ()
      in
      don't_wait_for
        (Progress.with_reporter
           (bar ~data:`Latest ~total:num_missing_targets "Downloading blocks")
           (fun f ->
             let rec progress_loop () =
               let%bind existing = list_directory ~network ~path:local_path in
               let downloaded_targets =
                 Set.length (Set.inter missing_targets existing)
               in
               f downloaded_targets ;
               let%bind () = after (Time.Span.of_sec 10.0) in
               if Deferred.is_determined gsutil_process then Deferred.unit
               else progress_loop ()
             in
             progress_loop () ) ) ;
      match%map gsutil_process with
      | Ok _ ->
          [%log info] "Finished downloading precomputed blocks"
      | Error err ->
          failwithf "Could not download batch of precomputed blocks: %s"
            (Error.to_string_hum err) ()
  in
  (* limit number of open files to avoid exceeding ulimits *)
  let file_throttle =
    Throttle.create ~continue_on_error:false ~max_concurrent_jobs:100
  in
  Deferred.List.map targets ~how:`Parallel ~f:(fun target ->
      let _, state_hash = target in
      let%map contents =
        Throttle.enqueue file_throttle (fun () ->
            Reader.file_contents
              (sprintf "%s/%s" local_path (Id.filename ~network target)) )
      in
      let block = of_yojson (Yojson.Safe.from_string contents) in
      (state_hash, block) )
  >>| Mina_base.State_hash.Map.of_alist_exn

let delete_fetched_concrete ~local_path ~network targets : unit Deferred.t =
  (* not perfect, but this is a reasonably portable default *)
  let max_args_size = (*16kb*) 16 * 1024 in
  (* break a list up into chunks using a fold operation *)
  let chunk_using list ~init ~f =
    let emit chunks_acc curr_acc =
      if List.is_empty curr_acc then chunks_acc
      else List.rev curr_acc :: chunks_acc
    in
    let rec loop list f_acc chunks_acc curr_acc =
      match list with
      | h :: t -> (
          match f f_acc h with
          | `Accumulate f_acc' ->
              loop t f_acc' chunks_acc (h :: curr_acc)
          | `Emit f_acc' ->
              loop t f_acc' (emit chunks_acc curr_acc) [] )
      | [] ->
          emit chunks_acc curr_acc
    in
    List.rev (loop list init [] [])
  in
  List.map targets ~f:(fun target ->
      sprintf "%s/%s" local_path (Id.filename ~network target) )
  |> chunk_using ~init:0 ~f:(fun accumulated_size block_id ->
         let arg_size = String.length block_id in
         let size_with_new_arg = accumulated_size + String.length block_id in
         if size_with_new_arg > max_args_size then `Emit arg_size
         else `Accumulate size_with_new_arg )
  |> Deferred.List.iter ~f:(fun files ->
         match%map Process.run ~prog:"rm" ~args:files () with
         | Ok _ ->
             ()
         | Error err ->
             failwithf "Could not delete fetched precomputed blocks, error %s"
               (Error.to_string_hum err) () )

let delete_fetched ~network ~path : unit Deferred.t =
  let%bind block_ids = list_directory ~network ~path in
  delete_fetched_concrete ~local_path:path ~network (Set.to_list block_ids)
