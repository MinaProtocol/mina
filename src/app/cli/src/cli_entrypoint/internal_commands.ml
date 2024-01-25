open Core
open Async
open Mina_base

let tx_snarks block =
  let f ({ fee; proofs; prover } : Transaction_snark_work.t) =
    let msg = Sok_message.create ~fee ~prover in
    One_or_two.to_list proofs |> List.map ~f:(Fn.flip Tuple2.create msg)
  in
  Mina_block.body block |> Staged_ledger_diff.Body.staged_ledger_diff
  |> Staged_ledger_diff.completed_works |> List.concat_map ~f

let blockchain_snark block =
  let open Mina_block in
  let header = header block in
  Blockchain_snark.Blockchain.create
    ~state:(Header.protocol_state header)
    ~proof:(Header.protocol_state_proof header)

let commands block =
  Mina_block.body block |> Staged_ledger_diff.Body.staged_ledger_diff
  |> Staged_ledger_diff.commands

let handle_result = function
  | Ok () ->
      Deferred.unit
  | Error (`Verification_error, err) ->
      printf "Verification_error: %s\n" (Error.to_string_hum err) ;
      exit 2
  | Error (`Invalid, err) ->
      printf "Invalid: %s\n" (Error.to_string_hum err) ;
      exit 1

let map_ver_result ~tag =
  Fn.compose
    (Result.map_error ~f:(Tuple2.map_snd ~f:(Error.tag ~tag)))
    (Fn.compose
       (Result.bind ~f:(Result.map_error ~f:(Tuple2.create `Invalid)))
       (Result.map_error ~f:(Tuple2.create `Verification_error)) )

let ledger_flag =
  let open Command.Param in
  flag "--ledger-directory" ~doc:"DIR Ledger directory" (required string)

let config_flag =
  let open Command.Param in
  flag "--config-file" ~doc:"FILE config file" (required string)

let repeat_tx_snarks_flag =
  let open Command.Param in
  flag "--repeat-tx-snarks" ~doc:"INT number of repetitions" (optional int)

let repeat_blockchain_snarks_flag =
  let open Command.Param in
  flag "--repeat-blockchain-snarks" ~doc:"INT number of repetitions"
    (optional int)

let repeat_commands_flag =
  let open Command.Param in
  flag "--repeat-commands"
    ~doc:"INT number of repetitions of the whole block processing"
    (optional int)

let repeat_flag =
  let open Command.Param in
  flag "--repeat" ~doc:"INT number of repetitions" (optional int)

let map_ver_commands_result =
  List.fold ~init:(Ok ()) ~f:(fun acc -> function
    | `Valid _ | `Valid_assuming _ ->
        acc
    | _ ->
        Error (Error.of_string "invalid_command") )

let pre_verify_block logger =
  Command.async
    ~summary:
      "Run verifier on block's snark proof, complete works and transactions \
       (block provided to stdin in binio encoding)"
    (let%map_open.Command ledger_dir = ledger_flag
     and config_file = config_flag
     and repeat = repeat_flag
     and repeat_tx_snarks = repeat_tx_snarks_flag
     and repeat_blockchain_snarks = repeat_blockchain_snarks_flag
     and repeat_commands = repeat_commands_flag in
     fun () ->
       let repeat_do ?(n = 1) ls = List.init n ~f:(const ls) |> List.concat in
       let precomputed_values =
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
       let open Async in
       let%bind precomputed_values =
         match%map precomputed_values with
         | Ok (precomputed_values, _) ->
             precomputed_values
         | Error err ->
             [%log fatal]
               "Failed initializing with configuration $config: $error"
               ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
             Error.raise err
       in
       let constraint_constants =
         Precomputed_values.constraint_constants precomputed_values
       in
       let logger = Logger.create () in
       Parallel.init_master () ;
       let%bind conf_dir = Unix.mkdtemp "/tmp/mina-verifier" in
       let module Block = Mina_block.Stable.Latest in
       let block_str = In_channel.(input_all stdin) in
       let buf = Bin_prot.Common.create_buf (String.length block_str) in
       Bin_prot.Common.blit_string_buf block_str ~len:(String.length block_str)
         buf ;
       let block = Block.bin_read_t ~pos_ref:(ref 0) buf in
       let%bind verifier =
         Verifier.create ~logger ~proof_level:Genesis_constants.Proof_level.Full
           ~constraint_constants ~pids:(Pid.Table.create ())
           ~conf_dir:(Some conf_dir) ()
       in
       let ledger =
         Mina_ledger.Ledger.create ~directory_name:ledger_dir
           ~depth:constraint_constants.ledger_depth ()
       in
       let tx_snarks = repeat_do ?n:repeat_tx_snarks @@ tx_snarks block in
       let blockchain_snarks =
         repeat_do ?n:repeat_blockchain_snarks [ blockchain_snark block ]
       in
       let%bind commands =
         let open Mina_ledger.Ledger in
         User_command.Last.to_all_verifiable (commands block)
           ~find_vk:
             (Zkapp_command.Verifiable.find_vk_via_ledger ~ledger ~get
                ~location_of_account )
         |> function
         | Ok cmds ->
             Deferred.return (repeat_do ?n:repeat_commands cmds)
         | Error e ->
             printf "Wrong ledger: %s\n" (Error.to_string_hum e) ;
             exit 4
       in
       Deferred.List.iter ~how:(`Max_concurrent_jobs 2)
         (List.init (Option.value ~default:1 repeat) ~f:Fn.id)
         ~f:(fun _ ->
           Deferred.bind ~f:handle_result
           @@ let%bind.Deferred.Result () =
                Verifier.verify_blockchain_snarks verifier blockchain_snarks
                >>| map_ver_result ~tag:"verify_blockchain_snark"
              in
              printf "Verifying %d transaction snarks\n" (List.length tx_snarks) ;
              let%bind.Deferred.Result () =
                Verifier.verify_transaction_snarks verifier tx_snarks
                >>| map_ver_result ~tag:"verify_transaction_snarks"
              in
              printf "Verifying %d commands\n" (List.length commands) ;
              let%map.Deferred.Result () =
                Verifier.verify_commands verifier commands
                >>| Result.map ~f:map_ver_commands_result
                >>| map_ver_result ~tag:"verify_commands"
              in
              printf "block proofs are valid\n" ) )
