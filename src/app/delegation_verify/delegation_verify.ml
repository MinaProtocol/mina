open Mina_base
open Core
open Async

type error =
  [ `Path_is_invalid
  | `Fail_to_load_metadata
  | `Fail_to_decode_metadata of string
  | `Fail_to_load_block
  | `Fail_to_decode_block
  | `Invalid_proof
  | `Fail_to_decode_snark_work
  | `Invalid_snark_work
  ]

let unify_error e = (e :> error)

let get_filenames =
  let open In_channel in
  function
  | [ "-" ] | [] ->
      input_all stdin |> String.split_lines
  | filenames ->
      filenames

let verify_block ~verify_blockchain_snarks ~block =
  let header = Mina_block.header block in
  let open Mina_block.Header in
  verify_blockchain_snarks
    [ (protocol_state header, protocol_state_proof header) ]
  |> Deferred.Result.map_error ~f:(const `Invalid_proof)

let verify_snark_work ~verify_transaction_snarks ~proof ~message =
  verify_transaction_snarks [ (proof, message) ]
  |> Deferred.Result.map_error ~f:(const `Invalid_snark_work)

module Validator(Sub : Submission.S) = struct
  let validate ~no_checks ~verify_blockchain_snarks ~verify_transaction_snarks submission =
    let open Deferred.Result.Let_syntax in
    let%bind block =
      Sub.block submission
      |> Result.map_error ~f:unify_error
      |> Deferred.return
    in
    let%bind () =
      if no_checks then return ()
      else verify_block ~verify_blockchain_snarks ~block
           |> Deferred.Result.map_error ~f:unify_error
    in
    let%map () =
      if no_checks then return ()
      else
        match Sub.snark_work submission with
        | None ->
           Deferred.Result.return ()
        | Some Uptime_service.Proof_data.
               { proof; proof_time = _; snark_work_fee } ->
           let message =
             Mina_base.Sok_message.create ~fee:snark_work_fee ~prover:(Sub.submitter submission)
           in
           verify_snark_work ~verify_transaction_snarks ~proof ~message
           |> Deferred.Result.map_error ~f:unify_error
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
end

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

let config_flag =
  let open Command.Param in
  flag "--config-file" ~doc:"FILE config file" (optional string)

let no_checks_flag =
  let open Command.Param in
  flag "--no-checks" ~aliases:[ "-no-checks" ]
    ~doc:"disable all the checks, just extract the info from the submissions"
    no_arg

let block_dir_flag =
  let open Command.Param in
  flag "--block-dir" ~aliases:[ "-block-dir" ]
    ~doc:"the path to the directory containing blocks for the submission"
    (required Filename.arg_type)

let instantiate_verify_functions ~logger = function
  | None ->
      Deferred.return
        (Verifier.verify_functions
           ~constraint_constants:Genesis_constants.Constraint_constants.compiled
           ~proof_level:Genesis_constants.Proof_level.compiled () )
  | Some config_file ->
      let%bind.Deferred precomputed_values =
        let%bind.Deferred.Or_error config_json =
          Genesis_ledger_helper.load_config_json config_file
        in
        let%bind.Deferred.Or_error config =
          Deferred.return
          @@ Result.map_error ~f:Error.of_string
          @@ Runtime_config.of_yojson config_json
        in
        Genesis_ledger_helper.init_from_config_file ~logger ~proof_level:None
          config
      in
      let%map.Deferred precomputed_values =
        match precomputed_values with
        | Ok (precomputed_values, _) ->
            Deferred.return precomputed_values
        | Error _ ->
            display_error "fail to read config file" ;
            exit 4
      in
      let constraint_constants =
        Precomputed_values.constraint_constants precomputed_values
      in
      Verifier.verify_functions ~constraint_constants ~proof_level:Full ()

let handle_error = function
  | `Path_is_invalid ->
     display_error "path for metadata is invalid" ;
     exit 1
  | `Fail_to_load_metadata ->
     display_error "fail to load metadata" ;
     exit 2
  | `Fail_to_decode_metadata e ->
     display_error ("fail to decode metadata: " ^ e) ;
     exit 2
  | `Fail_to_load_block ->
     display_error "fail to load block" ;
     exit 3
  | `Fail_to_decode_block ->
     display_error "fail to decode block" ;
     Deferred.unit
  | `Invalid_proof ->
     display_error
       "fail to verify the protocol state proof inside the block" ;
     Deferred.unit
  | `Fail_to_decode_snark_work ->
     display_error "fail to decode snark work" ;
     Deferred.unit
  | `Invalid_snark_work ->
     display_error "fail to verify the snark work" ;
     Deferred.unit

let command =
  Command.async
    ~summary:"A tool for verifying JSON payload submitted by the uptime service"
    Command.Let_syntax.(
      let%map_open block_dir = block_dir_flag
      and inputs = anon (sequence ("filename" %: Filename.arg_type))
      and no_checks = no_checks_flag
      and config_file = config_flag in
      fun () ->
        let logger = Logger.create () in
        let%bind.Deferred (verify_blockchain_snarks, verify_transaction_snarks) =
          instantiate_verify_functions ~logger config_file
        in
        let open Deferred.Let_syntax in
        let metadata_paths = get_filenames inputs in
        let module V = Validator(Submission.JSON) in
        Deferred.List.iter metadata_paths ~f:(fun path ->
            match%bind
              ( let open Deferred.Result.Let_syntax in
                let%bind submission =
                  Submission.JSON.load ~block_dir path
                  |> Result.map_error ~f:unify_error
                  |> Deferred.return
                in
                V.validate ~no_checks ~verify_blockchain_snarks ~verify_transaction_snarks submission)
            with
            | Ok (state_hash, parent, height, slot) ->
                display { state_hash; parent; height; slot } ;
                Deferred.unit
            | Error e ->
               handle_error e))

let () = Async.Command.run command
