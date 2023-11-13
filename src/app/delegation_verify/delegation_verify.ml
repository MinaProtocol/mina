open Mina_base
open Core
open Async

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

let verify_snark_work ~verify_transaction_snarks ~proof ~message =
  verify_transaction_snarks [ (proof, message) ]

module Validator (Sub : Submission.S) = struct
  let validate ~no_checks ~verify_blockchain_snarks ~verify_transaction_snarks
      submission =
    let open Deferred.Result.Let_syntax in
    let%bind block = Sub.block submission |> Deferred.return in
    let%bind () =
      if no_checks then return ()
      else verify_block ~verify_blockchain_snarks ~block
    in
    let%map () =
      if no_checks then return ()
      else
        match Sub.snark_work submission with
        | None ->
            Deferred.Result.return ()
        | Some
            Uptime_service.Proof_data.{ proof; proof_time = _; snark_work_fee }
          ->
            let message =
              Mina_base.Sok_message.create ~fee:snark_work_fee
                ~prover:(Sub.submitter submission)
            in
            verify_snark_work ~verify_transaction_snarks ~proof ~message
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
    , Consensus.Data.Consensus_state.global_slot_since_genesis consensus_state
    )
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

let cassandra_executable_flag =
  let open Command.Param in
  flag "--executable"
    ~aliases:[ "-executable"; "--cqlsh"; "-cqlsh" ]
    ~doc:"the path to the cqlsh executable"
    (optional Filename.arg_type)

let timestamp =
  let open Command.Param in
  anon ("timestamp" %: string)

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

let filesystem_command =
  Command.async ~summary:"Verify submissions and block read from the filesystem"
    Command.Let_syntax.(
      let%map_open block_dir = block_dir_flag
      and inputs = anon (sequence ("filename" %: Filename.arg_type))
      and no_checks = no_checks_flag
      and config_file = config_flag in
      fun () ->
        let logger = Logger.create () in
        let%bind.Deferred verify_blockchain_snarks, verify_transaction_snarks =
          instantiate_verify_functions ~logger config_file
        in
        let open Deferred.Let_syntax in
        let metadata_paths = get_filenames inputs in
        let module V = Validator (Submission.JSON) in
        Deferred.List.iter metadata_paths ~f:(fun path ->
            match%bind
              let open Deferred.Result.Let_syntax in
              let%bind submission =
                Submission.JSON.load ~block_dir path |> Deferred.return
              in
              V.validate ~no_checks ~verify_blockchain_snarks
                ~verify_transaction_snarks submission
            with
            | Ok (state_hash, parent, height, slot) ->
                display { state_hash; parent; height; slot } ;
                Deferred.unit
            | Error e ->
                display_error @@ Error.to_string_hum e ;
                Deferred.unit ))

let cassandra_command =
  Command.async ~summary:"Verify submissions and block read from Cassandra"
    Command.Let_syntax.(
      let%map_open cqlsh = cassandra_executable_flag
      and _period_start = timestamp
      and _period_end = timestamp in
      fun () ->
        let open Deferred.Let_syntax in
        match%bind
          Cassandra.exec ?cqlsh ~keyspace:"bpu_integration_dev"
          @@ Cassandra.query
               "SELECT JSON created_at, peer_id, snark_work, remote_addr, \
                submitter, block_hash, graphql_control_port FROM submissions;"
        with
        | Ok subs ->
            List.iter subs
              ~f:
                (Async.printf "submission: '%a'\n" (fun () s ->
                     Submission.JSON.raw_to_yojson s
                     |> Yojson.Safe.pretty_to_string ) ) ;
            Deferred.unit
        | Error e ->
            display_error @@ Error.to_string_hum e ;
            Deferred.unit)

let command =
  Command.group
    ~summary:"A tool for verifying JSON payload submitted by the uptime service"
    [ ("fs", filesystem_command); ("cassandra", cassandra_command) ]

let () = Async.Command.run command
