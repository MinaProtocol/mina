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
          HardForkSteps.get_migration_end_slot_for_state_hash conn_str_source_db
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
            conn_str_mainnet_source_db (Option.value_exn hash)
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
            conn_str_mainnet_source_db (Option.value_exn hash)
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
      , [ test_case "Test for testing incremental migration" `Quick
            HardForkTests.incremental
        ] )
    ]
