open Async
open Settings
open Steps
open Core
open Mina_automation

module HardForkTests = struct
  let random_migration env_file =
    let test_name = "random_migration" in
    let env = Settings.of_file_or_fail env_file in
    let temp_dir = Settings.working_dir env test_name in
    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
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
          HardForkSteps.get_latest_canonical_state_hash
            (Uri.of_string conn_str_source_db)
        in

        let migration_end_state_hash =
          migration_end_state_hash |> Option.value_exn
        in

        let input =
          Replayer.InputConfig.of_runtime_config_file_exn
            env.paths.random_data_ledger (Some migration_end_state_hash)
        in
        Replayer.InputConfig.to_yojson_file input reference_replayer_input ;
        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.random_data_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.random_data_bucket
            ~target_archive_uri:conn_str_target_db ~network:"mainnet"
            ~fork_block_hash:None
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:3
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.run_migration_verifier steps
            ~source_archive_uri:conn_str_source_db
            ~target_archive_uri:conn_str_target_db
            ~migrated_replayer_output:None ~fork_config_path:None
        in

        Deferred.unit )

  let incremental env_file =
    let env = Settings.of_file_or_fail env_file in
    let test_name = "incremental" in
    let temp_dir = Settings.working_dir env test_name in
    let reference_replayer_input =
      Filename.concat temp_dir "reference_replayer_input.json"
    in
    let actual_replayer_output =
      Filename.concat temp_dir "actual_replayer_output.json"
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        let steps = HardForkSteps.create env temp_dir test_name in
        let%bind conn_str_target_db =
          HardForkSteps.create_random_output_db steps
        in
        let%bind conn_str_source_db =
          HardForkSteps.build_mainnet_database steps ~num_blocks:10
        in

        let%bind max_hash =
          HardForkSteps.get_max_state_hash (Uri.of_string conn_str_source_db)
        in

        let input =
          Replayer.InputConfig.of_runtime_config_file_exn
            env.paths.mainnet_genesis_ledger max_hash
        in
        Replayer.InputConfig.to_yojson_file input reference_replayer_input ;

        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db ~network:"mainnet"
            ~fork_block_hash:max_hash
          (*this is a trick to convert pending blocks to canonical*)
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:1
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.run_migration_verifier steps
            ~source_archive_uri:conn_str_source_db
            ~target_archive_uri:conn_str_target_db
            ~migrated_replayer_output:None ~fork_config_path:None
        in

        let%bind blocks =
          HardForkSteps.download_mainnet_precomputed_blocks steps ~from:11
            ~num_blocks:10
        in
        let%bind _ =
          HardForkSteps.archive_mainnet_precomputed_blocks steps blocks
            conn_str_source_db
        in

        let%bind max_hash =
          HardForkSteps.get_max_state_hash (Uri.of_string conn_str_source_db)
        in
        let%bind _ =
          HardForkSteps.perform_berkeley_migration steps ~batch_size:2
            ~genesis_ledger:env.paths.mainnet_genesis_ledger
            ~source_archive_uri:conn_str_source_db
            ~source_blocks_bucket:env.paths.mainnet_data_bucket
            ~target_archive_uri:conn_str_target_db ~network:"mainnet"
            ~fork_block_hash:max_hash
        in

        let%bind _ =
          HardForkSteps.run_migration_replayer steps
            ~archive_uri:conn_str_target_db
            ~input_config:reference_replayer_input ~interval_checkpoint:1
            ~output_ledger:actual_replayer_output
        in

        let%bind _ =
          HardForkSteps.run_migration_verifier steps
            ~source_archive_uri:conn_str_source_db
            ~target_archive_uri:conn_str_target_db
            ~migrated_replayer_output:None ~fork_config_path:None
        in
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
    [ ( "random_migration"
      , [ test_case "Test for short global slots on artificial data" `Quick
            HardForkTests.random_migration
        ] )
    ; ( "incremental"
      , [ test_case "Test for testing incremental migration" `Quick
            HardForkTests.incremental
        ] )
    ]
