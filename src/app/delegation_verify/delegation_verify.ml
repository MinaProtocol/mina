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

let verify_snark_work ~verify_transaction_snarks ~proof ~message =
  verify_transaction_snarks [ (proof, message) ]

let config_flag = Cli_lib.Flag.conf_file

let keyspace_flag =
  let open Command.Param in
  flag "--keyspace" ~doc:"Name of the Cassandra keyspace" (required string)

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

let instantiate_verify_functions ~logger ~cli_proof_level config_file =
  let open Deferred.Let_syntax in
  let%map constants =
    Runtime_config.Constants.load_constants ~logger ~cli_proof_level config_file
  in
  let constraint_constants =
    Runtime_config.Constants.constraint_constants constants
  in
  Verifier.verify_functions ~constraint_constants ~proof_level:Full ()

module Make_verifier (Source : Submission.Data_source) = struct
  let verify_transaction_snarks = Source.verify_transaction_snarks

  let verify_blockchain_snarks = Source.verify_blockchain_snarks

  let intialize_submission ?validate (src : Source.t) (sub : Source.submission)
      =
    let block_hash = Source.block_hash sub in
    if Known_blocks.is_known block_hash then ()
    else
      Known_blocks.add ?validate ~verify_blockchain_snarks ~block_hash
        (Source.load_block sub src)

  let verify ~validate (submission : Source.submission) =
    let open Deferred.Result.Let_syntax in
    let block_hash = Source.block_hash submission in
    let%bind block = Known_blocks.get block_hash in
    let%bind () = Known_blocks.is_valid block_hash in
    let%map () =
      if validate then
        match%bind Deferred.return @@ Source.snark_work submission with
        | None ->
            Deferred.Result.return ()
        | Some
            Uptime_service.Proof_data.{ proof; proof_time = _; snark_work_fee }
          ->
            let message =
              Mina_base.Sok_message.create ~fee:snark_work_fee
                ~prover:(Source.submitter submission)
            in
            verify_snark_work ~verify_transaction_snarks ~proof ~message
      else return ()
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

  let validate_and_display_results ~validate ~src submission =
    let open Deferred.Let_syntax in
    let%bind result = verify ~validate submission in
    Result.map result ~f:(fun (state_hash, parent, height, slot) ->
        Output.
          { submitted_at = Source.submitted_at submission
          ; submitter =
              Signature_lib.Public_key.Compressed.to_base58_check
                (Source.submitter submission)
          ; state_hash
          ; parent
          ; height
          ; slot
          } )
    |> Source.output src submission

  let process ?(validate = true) (src : Source.t) =
    let open Deferred.Or_error.Let_syntax in
    let%bind submissions = Source.load_submissions src in
    List.iter submissions ~f:(intialize_submission ~validate src) ;
    List.map submissions ~f:(validate_and_display_results ~src ~validate)
    |> Deferred.Or_error.all_unit
end

let filesystem_command ~logger =
  Command.async ~summary:"Verify submissions and block read from the filesystem"
    Command.Let_syntax.(
      let%map_open block_dir = block_dir_flag
      and inputs = anon (sequence ("filename" %: Filename.arg_type))
      and no_checks = no_checks_flag
      and config_file = config_flag in
      fun () ->
        let%bind.Deferred verify_blockchain_snarks, verify_transaction_snarks =
          instantiate_verify_functions ~logger ~cli_proof_level:None config_file
        in

        let submission_paths = get_filenames inputs in
        let module V = Make_verifier (struct
          include Submission.Filesystem

          let verify_blockchain_snarks = verify_blockchain_snarks

          let verify_transaction_snarks = verify_transaction_snarks
        end) in
        let open Deferred.Let_syntax in
        match%bind
          V.process ~validate:(not no_checks) { submission_paths; block_dir }
        with
        | Ok () ->
            Deferred.unit
        | Error e ->
            Output.display_error @@ Error.to_string_hum e ;
            exit 1)

let cassandra_command ~logger =
  Command.async ~summary:"Verify submissions and block read from Cassandra"
    Command.Let_syntax.(
      let%map_open cqlsh = cassandra_executable_flag
      and no_checks = no_checks_flag
      and config_file = config_flag
      and keyspace = keyspace_flag
      and period_start = timestamp
      and period_end = timestamp in
      fun () ->
        let open Deferred.Let_syntax in
        let%bind.Deferred verify_blockchain_snarks, verify_transaction_snarks =
          instantiate_verify_functions ~logger ~cli_proof_level:None config_file
        in
        let module V = Make_verifier (struct
          include Submission.Cassandra

          let verify_blockchain_snarks = verify_blockchain_snarks

          let verify_transaction_snarks = verify_transaction_snarks
        end) in
        let src =
          Submission.Cassandra.
            { conf = Cassandra.make_conf ?executable:cqlsh ~keyspace
            ; period_start
            ; period_end
            }
        in
        match%bind V.process ~validate:(not no_checks) src with
        | Ok () ->
            Deferred.unit
        | Error e ->
            Output.display_error @@ Error.to_string_hum e ;
            exit 1)

let stdin_command ~logger =
  Command.async
    ~summary:"Verify submissions and blocks read from standard input"
    Command.Let_syntax.(
      let%map_open config_file = config_flag and no_checks = no_checks_flag in
      fun () ->
        let open Deferred.Let_syntax in
        let%bind.Deferred verify_blockchain_snarks, verify_transaction_snarks =
          instantiate_verify_functions ~logger ~cli_proof_level:None config_file
        in
        let module V = Make_verifier (struct
          include Submission.Stdin

          let verify_blockchain_snarks = verify_blockchain_snarks

          let verify_transaction_snarks = verify_transaction_snarks
        end) in
        match%bind V.process ~validate:(not no_checks) () with
        | Ok () ->
            Deferred.unit
        | Error e ->
            Output.display_error @@ Error.to_string_hum e ;
            exit 1)

let command ~logger =
  Command.group
    ~summary:"A tool for verifying JSON payload submitted by the uptime service"
    [ ("fs", filesystem_command ~logger)
    ; ("cassandra", cassandra_command ~logger)
    ; ("stdin", stdin_command ~logger)
    ]

let () =
  let logger = Logger.create () in
  Async.Command.run @@ command ~logger
