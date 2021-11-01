open Mina_base
open Mina_transition
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
  match Yojson.Safe.from_string str |> metadata_of_yojson with
  | Ok
      { created_at = _
      ; peer_id = _
      ; snark_work
      ; remote_addr = _
      ; submitter
      ; block_hash
      } -> (
      match submitter |> Public_key.Compressed.of_base58_check with
      | Ok submitter ->
          Ok (snark_work, submitter, block_hash)
      | Error _ ->
          Error `Fail_to_decode_metadata )
  | Error _ ->
      Error `Fail_to_decode_metadata

let load_block ~block_dir ~block_hash =
  let block_path = Filename.concat block_dir (block_hash ^ ".dat") in
  try Ok (In_channel.read_all block_path) with _ -> Error `Fail_to_load_block

let decode_block str =
  try Ok (Binable.of_string (module External_transition.Stable.Latest) str)
  with _ -> Error `Fail_to_decode_block

let verify_block ~block =
  let open External_transition in
  let%map result =
    Verifier.verify_blockchain_snarks
      [ Blockchain_snark.Blockchain.create ~state:(protocol_state block)
          ~proof:(protocol_state_proof block)
      ]
  in
  if result then Ok () else Error `Invalid_proof

let decode_snark_work str =
  match Base64.decode str with
  | Ok str -> (
      try Ok (Binable.of_string (module Uptime_service.Proof_data) str)
      with _ -> Error `Fail_to_decode_snark_work )
  | Error _ ->
      Error `Fail_to_decode_snark_work

let verify_snark_work ~proof ~message =
  let%map result = Verifier.verify_transaction_snarks [ (proof, message) ] in
  if result then Ok () else Error `Invalid_snark_work

let validate_submission ~block_dir ~metadata_path =
  let open Deferred.Result.Let_syntax in
  let%bind () = Deferred.return @@ check_path metadata_path in
  let%bind metadata_str = Deferred.return @@ load_metadata metadata_path in
  let%bind snark_work_opt, submitter, block_hash =
    Deferred.return @@ decode_metadata metadata_str
  in
  let%bind block_str = Deferred.return @@ load_block ~block_dir ~block_hash in
  let%bind block = Deferred.return @@ decode_block block_str in
  let%bind () = verify_block ~block in
  let%map () =
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
  ( External_transition.state_hash block
  , External_transition.blockchain_length block
  , External_transition.global_slot block )

type valid_payload =
  { state_hash : State_hash.t
  ; height : Unsigned.uint32
  ; slot : Unsigned.uint32
  }

let valid_payload_to_yojson { state_hash; height; slot } : Yojson.Safe.t =
  `Assoc
    [ ("state_hash", State_hash.to_yojson state_hash)
    ; ("height", `Int (Unsigned.UInt32.to_int height))
    ; ("slot", `Int (Unsigned.UInt32.to_int slot))
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
      and inputs = anon (sequence ("filename" %: Filename.arg_type)) in
      fun () ->
        let open Deferred.Let_syntax in
        let metadata_pathes = get_filenames inputs in
        Deferred.List.iter metadata_pathes ~f:(fun metadata_path ->
            match%bind validate_submission ~block_dir ~metadata_path with
            | Ok (state_hash, height, slot) ->
                display { state_hash; height; slot } ;
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
                Deferred.unit))

let () = Rpc_parallel.start_app command
