open Async
open Settings
open Steps
open Core

module HardForkTests = struct
  let mainnet_migration env_file =
    let test_name = "mainnet_migration" in
    let env = Settings.of_file_or_fail env_file in
    let temp_dir = Settings.working_dir env test_name in
    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
    in
    let reference_replayer_output =
      Filename.concat temp_dir "reference_replayer_output.json"
    in
    let actual_replayer_output =
      Filename.concat temp_dir "actual_replayer_output.json"
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        let open Deferred.Let_syntax in
        let steps = HardForkSteps.create env temp_dir test_name in
        let%bind () = HardForkSteps.recreate_working_dir steps in
        let%bind conn_str_source_db =
          HardForkSteps.import_mainnet_dump steps "2023-11-02"
        in

        let migration_end_slot = 200 in
        let%bind migration_end_state_hash =
          HardForkSteps.get_latest_state_hash_at_slot
            (Uri.of_string conn_str_source_db)
            migration_end_slot
        in

        let input =
          BerkeleyTablesAppInput.of_runtime_config_file_exn
            env.paths.mainnet_genesis_ledger (Some migration_end_state_hash)
        in
        BerkeleyTablesAppInput.to_yojson_file input reference_replayer_input ;

        let%bind _ =
          HardForkSteps.run_compatible_replayer steps conn_str_source_db
            ~input_file:(Filename.basename reference_replayer_input)
            ~output_file:(Filename.basename reference_replayer_output)
            ~clear_checkpoints:true
        in

        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:(Some migration_end_slot)
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:10
            ~replayer_app:env.paths.replayer
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.compare_hashes conn_str_source_db conn_str_target_db
            migration_end_slot ~should_contain_pending_blocks:false
        in
        HardForkSteps.compare_replayer_outputs reference_replayer_output
          actual_replayer_output ~compare_receipt_chain_hashes:false ;
        Deferred.unit )

  let random_migration env_file =
    let test_name = "random_migration" in
    let env = Settings.of_file_or_fail env_file in
    let temp_dir = Settings.working_dir env test_name in
    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
    in
    let reference_replayer_output =
      Filename.concat temp_dir "reference_replayer_output.json"
    in
    let actual_replayer_output =
      Filename.concat temp_dir "actual_replayer_output.json"
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        let steps = HardForkSteps.create env temp_dir test_name in
        let open Deferred.Let_syntax in
        let%bind _ = HardForkSteps.recreate_working_dir steps in

        let%bind conn_str_source_db =
          HardForkSteps.import_random_data_dump steps
        in

        let%bind migration_end_state_hash =
          HardForkSteps.get_latest_state_hash (Uri.of_string conn_str_source_db)
        in

        let migration_end_state_hash =
          migration_end_state_hash |> Option.value_exn
        in

        let input =
          BerkeleyTablesAppInput.of_runtime_config_file_exn
            env.paths.random_data_ledger (Some migration_end_state_hash)
        in
        BerkeleyTablesAppInput.to_yojson_file input reference_replayer_input ;

        let%bind _ =
          HardForkSteps.run_compatible_replayer steps conn_str_source_db
            ~input_file:(Filename.basename reference_replayer_input)
            ~output_file:(Filename.basename reference_replayer_output)
            ~clear_checkpoints:true
        in
        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in
        let%bind migration_end_slot =
          HardForkSteps.get_migration_end_slot_for_state_hash (Uri.of_string conn_str_source_db)
            migration_end_state_hash
        in
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.random_data_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.random_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:(Some migration_end_slot)
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:10
            ~replayer_app:env.paths.replayer
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.compare_hashes conn_str_source_db conn_str_target_db
            migration_end_slot ~should_contain_pending_blocks:true
        in
        HardForkSteps.compare_replayer_outputs reference_replayer_output
          actual_replayer_output ~compare_receipt_chain_hashes:false ;
        Deferred.unit )

 let daemon env_file =
    let test_name = "daemon" in
    let env = Settings.of_file_or_fail env_file in
    let temp_dir = Settings.working_dir env test_name in
    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
    in
    let reference_replayer_output =
      Filename.concat temp_dir "reference_replayer_output.json"
    in
    let actual_replayer_output =
      Filename.concat temp_dir "actual_replayer_output.json"
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        let steps = HardForkSteps.create env temp_dir test_name in
        let open Deferred.Let_syntax in
        let%bind _ = HardForkSteps.recreate_working_dir steps in

        let%bind conn_str_source_db =
          HardForkSteps.import_random_data_dump steps
        in

        let%bind last_canonical_hash = HardForkSteps.get_latest_canonical_state_hash (Uri.of_string conn_str_source_db) in

        let input =
          BerkeleyTablesAppInput.of_runtime_config_file_exn
            env.paths.random_data_ledger last_canonical_hash
        in
        BerkeleyTablesAppInput.to_yojson_file input reference_replayer_input ;

        let%bind _ =
          HardForkSteps.run_compatible_replayer steps conn_str_source_db
            ~input_file:(Filename.basename reference_replayer_input)
            ~output_file:(Filename.basename reference_replayer_output)
            ~clear_checkpoints:true
        in
        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in
        
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.random_data_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.random_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:None
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:100
            ~replayer_app:env.paths.replayer
            ~output_ledger:actual_replayer_output
        in

        let genesis: Runtime_config.Json_layout.Genesis.t = { 
          k = None 
        ; delta = None
        ; slots_per_epoch = None
        ; slots_per_sub_window = None
        ; grace_period_slots = None
        ; genesis_state_timestamp = Some "2024-01-18T21:59:37+0100"
        }
      in

      let migration_replayer_output =
          BerkeleyTablesAppOutput.of_json_file_exn (Printf.sprintf "%s/actual_replayer_output.json" steps.working_dir)
      in

      let%bind previous_global_slot = HardForkSteps.get_migration_end_slot_for_state_hash (Uri.of_string conn_str_source_db) (Option.value_exn last_canonical_hash) in 
      let%bind previous_length = HardForkSteps.get_blockchain_length_for_state_hash (Uri.of_string conn_str_source_db) (Option.value_exn last_canonical_hash) in 


      let fork : Runtime_config.Fork_config.t = {
        previous_state_hash = Mina_base.State_hash.to_base58_check migration_replayer_output.target_fork_state_hash
        ; previous_length = Option.value_exn previous_length
        ; previous_global_slot = previous_global_slot + 1 
        }
      in
      let proof = Runtime_config.Proof_keys.make ~fork () in

      Unix.putenv ~key:"MINA_LIBP2P_PASS" ~data:"" ;
      Unix.putenv ~key:"MINA_PRIVKEY_PASS" ~data:"" ;
   
      let%bind _ = HardForkSteps.generate_keypair steps "keys/block_producer.key" in
      let%bind _ = HardForkSteps.generate_keypair steps "keys/snark_producer.key" in
      let%bind _ = HardForkSteps.generate_libp2p_keypair steps "keys/libp2p-keypair" in 

      let block_producer_pk = In_channel.read_all (Filename.concat temp_dir "keys/block_producer.key.pub") |> String.strip in
      let _snark_producer_pk = In_channel.read_all (Filename.concat temp_dir "keys/snark_producer.key.pub") |> String.strip in

      let new_base = match migration_replayer_output.target_genesis_ledger.base with
        | Named _  -> failwith "wrong genesis" 
        | Accounts accounts -> 
          let additional_account: Runtime_config.Accounts.Single.t = {
             pk = block_producer_pk
            ; sk = None
            ; balance = Currency.Balance.of_mina_int_exn 1000000000
            ; delegate = None
            ; timing = None
            ; token = None
            ; nonce = Mina_numbers.Account_nonce.of_int 0
            ; receipt_chain_hash = None
            ; voting_for = None
            ; zkapp = None
            ; permissions = None
            ; token_symbol = None
          }
          in          
          accounts @ [additional_account]
          
        | Hash _ ->  failwith "wrong genesis" 
      in

      let ledger: Runtime_config.Ledger.t = {
        base = Runtime_config.Ledger.Accounts new_base
      ; num_accounts = migration_replayer_output.target_genesis_ledger.num_accounts
      ; balances = migration_replayer_output.target_genesis_ledger.balances
      ; hash = migration_replayer_output.target_genesis_ledger.hash
      ; name = migration_replayer_output.target_genesis_ledger.name
      ; add_genesis_winner = migration_replayer_output.target_genesis_ledger.add_genesis_winner
      } 
      in

      let runtime_config = Runtime_config.make ~genesis ~ledger ~proof () in
      let config_filename = (Printf.sprintf "%s/daemon.json" steps.working_dir) in

        Runtime_config.to_yojson runtime_config |> 
        Yojson.Safe.to_file config_filename;

      
      let%bind archive_process =  HardForkSteps.start_archive_node steps config_filename conn_str_target_db in
      let _archive_process = archive_process |> Or_error.ok_exn in
      Unix.sleep 10;

      let%bind daemon_process =  HardForkSteps.start_seed_deamon_node steps ~block_producer_key ~config_file ~libp2p_keypair "127.0.0.1:3086" in
      let _archive_process = daemon_process |> Or_error.ok_exn in
      Unix.sleep 100;



      Deferred.unit 
        
        )

  let checkpoint env_file =
    let test_name = "checkpoint" in
    let env = Settings.of_file_or_fail env_file in
    let temp_dir = Settings.working_dir env test_name in

    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
    in
    let reference_replayer_output =
      Filename.concat temp_dir "reference_replayer_output.json"
    in
    let actual_replayer_output =
      Filename.concat temp_dir "actual_replayer_output.json"
    in
    let actual_replayer_input =
      Filename.concat temp_dir "actual_replayer_input.json"
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        let steps = HardForkSteps.create env temp_dir test_name in
        let open Deferred.Let_syntax in
        let%bind _ = HardForkSteps.recreate_working_dir steps in

        let%bind conn_str_source_db =
          HardForkSteps.import_mainnet_dump steps "2023-11-02"
        in

        let migration_end_slot = 200 in
        let%bind migration_end_state_hash =
          HardForkSteps.get_latest_state_hash_at_slot
            (Uri.of_string conn_str_source_db)
            migration_end_slot
        in
        let input =
          BerkeleyTablesAppInput.of_runtime_config_file_exn
            env.paths.mainnet_genesis_ledger (Some migration_end_state_hash)
        in
        BerkeleyTablesAppInput.to_yojson_file input reference_replayer_input ;

        let%bind _ =
          HardForkSteps.run_compatible_replayer steps conn_str_source_db
            ~input_file:(Filename.basename reference_replayer_input)
            ~output_file:(Filename.basename reference_replayer_output)
            ~clear_checkpoints:true
        in

        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in

        (* first we migrate half of slots *)
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:(Some (migration_end_slot / 2))
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let input =
          BerkeleyTablesAppInput.of_runtime_config_file_exn
            env.paths.mainnet_genesis_ledger None
        in
        BerkeleyTablesAppInput.to_yojson_file input actual_replayer_input ;

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db ~input_config:actual_replayer_input
            ~interval_checkpoint:10 ~replayer_app:env.paths.replayer
            ~output_ledger:"temp_ledger.json"
        in

        let checkpoints =
          HardForkSteps.gather_replayer_migration_checkpoint_files temp_dir
        in

        (* then we migrate second half of slots *)
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:(Some migration_end_slot)
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let actual_input =
          BerkeleyTablesAppInput.of_checkpoint_file
            (List.last_exn checkpoints)
            (Some migration_end_state_hash)
        in
        BerkeleyTablesAppInput.to_yojson_file actual_input actual_replayer_input ;

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db ~input_config:actual_replayer_input
            ~interval_checkpoint:10 ~replayer_app:env.paths.replayer
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.compare_hashes conn_str_source_db conn_str_target_db
            migration_end_slot ~should_contain_pending_blocks:false
        in
        HardForkSteps.compare_replayer_outputs reference_replayer_output
          actual_replayer_output ~compare_receipt_chain_hashes:false ;
        Deferred.unit )

  let incremental env_file =
    let env = Settings.of_file_or_fail env_file in
    let test_name = "incremental" in
    let temp_dir = Settings.working_dir env test_name in
    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
    in
    let reference_replayer_output =
      Filename.concat temp_dir "reference_replayer_output.json"
    in
    let actual_replayer_output =
      Filename.concat temp_dir "actual_replayer_output.json"
    in

    Async.Thread_safe.block_on_async_exn (fun () ->
        let steps = HardForkSteps.create env temp_dir test_name in
        let%bind conn_str_mainnet_source_db =
          HardForkSteps.import_genesis_mainnet_dump steps
        in
        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in

        let%bind blocks =
          HardForkSteps.download_mainnet_precomputed_blocks steps ~from:2
            ~num_blocks:10
        in
        let%bind _ =
          HardForkSteps.archive_mainnet_precomputed_blocks steps blocks
            conn_str_mainnet_source_db
        in
        let%bind hash =
          HardForkSteps.get_max_state_hash
            (Uri.of_string conn_str_mainnet_source_db)
        in
        let%bind migration_end_slot =
          HardForkSteps.get_migration_end_slot_for_state_hash
            (Uri.of_string conn_str_mainnet_source_db) (Option.value_exn hash)
        in

        let input =
          BerkeleyTablesAppInput.of_runtime_config_file_exn
            env.paths.mainnet_genesis_ledger hash
        in
        BerkeleyTablesAppInput.to_yojson_file input reference_replayer_input ;

        let%bind _ =
          HardForkSteps.run_compatible_replayer steps conn_str_mainnet_source_db
            ~input_file:(Filename.basename reference_replayer_input)
            ~output_file:(Filename.basename reference_replayer_output)
            ~clear_checkpoints:true
        in

        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_mainnet_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:(Some migration_end_slot)
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:1
            ~replayer_app:env.paths.replayer
            ~output_ledger:actual_replayer_output
        in

        HardForkSteps.assert_no_replayer_migration_checkpoint_on_pending_blocks
          temp_dir ;
        let%bind _ =
          HardForkSteps.compare_hashes conn_str_mainnet_source_db
            conn_str_target_db migration_end_slot
            ~should_contain_pending_blocks:true
        in
        HardForkSteps.compare_replayer_outputs reference_replayer_output
          actual_replayer_output ~compare_receipt_chain_hashes:false ;

        let%bind blocks =
          HardForkSteps.download_mainnet_precomputed_blocks steps ~from:11
            ~num_blocks:10
        in
        let%bind _ =
          HardForkSteps.archive_mainnet_precomputed_blocks steps blocks
            conn_str_mainnet_source_db
        in
        let%bind hash =
          HardForkSteps.get_max_state_hash
            (Uri.of_string conn_str_mainnet_source_db)
        in
        let%bind migration_end_slot =
          HardForkSteps.get_migration_end_slot_for_state_hash
          (Uri.of_string conn_str_mainnet_source_db) (Option.value_exn hash)
        in

        let%bind _ =
          HardForkSteps.run_compatible_replayer steps conn_str_mainnet_source_db
            ~input_file:(Filename.basename reference_replayer_input)
            ~output_file:(Filename.basename reference_replayer_output)
            ~clear_checkpoints:true
        in

        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_mainnet_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db
            ~end_global_slot:(Some migration_end_slot)
            ~berkeley_migration_app:env.paths.berkeley_migration
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:1
            ~replayer_app:env.paths.replayer
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.compare_hashes conn_str_mainnet_source_db
            conn_str_target_db migration_end_slot
            ~should_contain_pending_blocks:true
        in
        HardForkSteps.compare_replayer_outputs reference_replayer_output
          actual_replayer_output ~compare_receipt_chain_hashes:false ;
        Deferred.unit )
end

let env =
  let doc = "Path Path to env file" in
  Cmdliner.Arg.(
    required
    & opt (some string) None
    & info [ "env" ] ~doc ~docv:"HARDFORK_TEST_ENV_FILE")

let () =
  let open Alcotest in
  run_with_args "Hardfork test suite." env
    [ ( "mainnet_migration"
      , [ test_case "Test for short global slots on mainnet data" `Quick
            HardForkTests.mainnet_migration
        ] )
    ; ( "random_migration"
      , [ test_case "Test for short global slots on artificial data" `Quick
            HardForkTests.random_migration
        ] )
    ; ( "checkpoints"
      , [ test_case "Test for checkpoint in migration process" `Quick
            HardForkTests.checkpoint
        ] )
    ; ( "incremental"
      , [ test_case "Test for incremental migration" `Quick
            HardForkTests.incremental
        ] )
    ; ( "daemon"
    , [ test_case "Test for launching node on migrated data" `Quick
          HardForkTests.daemon
      ] )
    ]
