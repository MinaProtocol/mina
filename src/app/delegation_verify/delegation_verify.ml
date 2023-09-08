open Mina_base
open Core
open Async
open Signature_lib

type metadata =
  { created_at : string
  ; peer_id : string
  ; snark_work : string option [@default None]
  ; remote_addr : string
  ; submitter : string
  ; block_hash : string
  }
[@@deriving yojson]

let get_filenames =
  let open In_channel in
  function
  | [ "-" ] | [] ->
      input_all stdin |> String.split_lines
  | filenames ->
      filenames

(* This check seems unnecessary if the submission data is published by ourselfes *)
let check_path _ = Ok ()

let load_metadata str =
  try Ok (In_channel.read_all str) with _ -> Error `Fail_to_load_metadata

(* This decoding is also unnecessarily complicated given that we are the creator of those data *)
let decode_metadata str =
  let parsed_meta =
    match Yojson.Safe.from_string str |> metadata_of_yojson with
    | Ppx_deriving_yojson_runtime.Result.Ok a ->
        Ok a
    | Ppx_deriving_yojson_runtime.Result.Error _ ->
        Error `Fail_to_decode_metadata
  in
  let%bind.Result { snark_work; submitter; block_hash; _ } = parsed_meta in
  let%bind.Result submitter =
    Result.map_error ~f:(const `Fail_to_decode_metadata)
    @@ Public_key.Compressed.of_base58_check submitter
  in
  Ok (snark_work, submitter, block_hash)

let load_block ~block_dir ~block_hash =
  let block_path = Filename.concat block_dir (block_hash ^ ".dat") in
  try Ok (In_channel.read_all block_path) with _ -> Error `Fail_to_load_block

let decode_block str =
  try Ok (Binable.of_string (module Mina_block.Stable.Latest) str)
  with _ -> Error `Fail_to_decode_block

let verify_block ~block =
  let header = Mina_block.header block in
  let open Mina_block.Header in
  let verify_blockchain_snarks, _ = force Verifier.verify_functions in
  verify_blockchain_snarks
    [ (protocol_state header, protocol_state_proof header) ]
  |> Deferred.Result.map_error ~f:(const `Invalid_proof)

let decode_snark_work str =
  match Base64.decode str with
  | Ok str -> (
      try Ok (Binable.of_string (module Uptime_service.Proof_data) str)
      with _ -> Error `Fail_to_decode_snark_work )
  | Error _ ->
      Error `Fail_to_decode_snark_work

let verify_snark_work ~proof ~message =
  let _, verify_transaction_snarks = force Verifier.verify_functions in
  verify_transaction_snarks [ (proof, message) ]
  |> Deferred.Result.map_error ~f:(const `Invalid_snark_work)

let validate_submission ~block_dir ~metadata_path ~no_checks =
  let open Deferred.Result.Let_syntax in
  let%bind () = Deferred.return @@ check_path metadata_path in
  let%bind metadata_str = Deferred.return @@ load_metadata metadata_path in
  let%bind snark_work_opt, submitter, block_hash =
    Deferred.return @@ decode_metadata metadata_str
  in
  let%bind block_str = Deferred.return @@ load_block ~block_dir ~block_hash in
  let%bind block = Deferred.return @@ decode_block block_str in
  let%bind () = if no_checks then return () else verify_block ~block in
  let%map () =
    if no_checks then return ()
    else
      match snark_work_opt with
      | None ->
          Deferred.Result.return ()
      | Some snark_work_str ->
          let%bind Uptime_service.Proof_data.
                     { proof; proof_time = _; snark_work_fee } =
            Deferred.return @@ decode_snark_work snark_work_str
          in
          let message =
            Mina_base.Sok_message.create ~fee:snark_work_fee ~prover:submitter
          in
          verify_snark_work ~proof ~message
  in
  let header = Mina_block.header block in
  let protocol_state = Mina_block.Header.protocol_state header in
  let consensus_state =
    Mina_state.Protocol_state.consensus_state protocol_state
  in
  ( Mina_state.Protocol_state.hashes protocol_state
    |> State_hash.State_hashes.state_hash
  , Mina_state.Protocol_state.previous_state_hash protocol_state
  , Consensus.Data.Consensus_state.blockchain_length consensus_state
  , Consensus.Data.Consensus_state.global_slot_since_genesis consensus_state )

type valid_payload =
  { state_hash : State_hash.t
  ; parent : State_hash.t
  ; height : Unsigned.uint32
  ; slot : Mina_numbers.Global_slot_since_genesis.t
  }

let valid_payload_to_yojson { state_hash; parent; height; slot } : Yojson.Safe.t
    =
  `Assoc
    [ ("state_hash", State_hash.to_yojson state_hash)
    ; ("parent", State_hash.to_yojson parent)
    ; ("height", `Int (Unsigned.UInt32.to_int height))
    ; ("slot", `Int (Mina_numbers.Global_slot_since_genesis.to_int slot))
    ]

let display valid_payload =
  printf "%s\n" @@ Yojson.Safe.to_string
  @@ valid_payload_to_yojson valid_payload

let display_error e =
  eprintf "%s\n" @@ Yojson.Safe.to_string @@ `Assoc [ ("error", `String e) ]

let command =
  Command.async
    ~summary:"A tool for verifying JSON payload submitted by the uptime service"
    Command.Let_syntax.(
      let%map_open block_dir =
        flag "--block-dir" ~aliases:[ "-block-dir" ]
          ~doc:"the path to the directory containing blocks for the submission"
          (required Filename.arg_type)
      and inputs = anon (sequence ("filename" %: Filename.arg_type))
      and no_checks =
        flag "--no-checks" ~aliases:[ "-no-checks" ]
          ~doc:
            "disable all the checks, just extract the info from the submissions"
          no_arg
      in
      fun () ->
        let open Deferred.Let_syntax in
        let metadata_pathes = get_filenames inputs in
        Deferred.List.iter metadata_pathes ~f:(fun metadata_path ->
            match%bind
              validate_submission ~block_dir ~metadata_path ~no_checks
            with
            | Ok (state_hash, parent, height, slot) ->
                display { state_hash; parent; height; slot } ;
                Deferred.unit
            | Error `Path_is_invalid ->
                display_error "path for metadata is invalid" ;
                exit 1
            | Error `Fail_to_load_metadata | Error `Fail_to_decode_metadata ->
                display_error "fail to load metadata" ;
                exit 2
            | Error `Fail_to_load_block ->
                display_error "fail to load block" ;
                exit 3
            | Error `Fail_to_decode_block ->
                display_error "fail to decode block" ;
                Deferred.unit
            | Error `Invalid_proof ->
                display_error
                  "fail to verify the protocol state proof inside the block" ;
                Deferred.unit
            | Error `Fail_to_decode_snark_work ->
                display_error "fail to decode snark work" ;
                Deferred.unit
            | Error `Invalid_snark_work ->
                display_error "fail to verify the snark work" ;
                Deferred.unit ))

let () = Async.Command.run command
