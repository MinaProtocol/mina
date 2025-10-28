(** Main entry point for the packaged fork configuration verification tool.

    This application orchestrates the complete verification process for
    Mina packaged fork configurations, including ledger generation,
    daemon export, and comprehensive comparison validation.
*)

open Core
open Async

(* Import all library modules *)
open Verify_packaged_fork_config_lib

(** Extract ledgers from a running daemon.

    This function:
    1. Starts a Mina daemon with specified config
    2. Waits for daemon readiness
    3. Exports staged, staking, and next epoch ledgers
    4. Stops the daemon

    @param config Validation configuration
    @param config_file Path to daemon configuration file
    @param ledger_dir Directory containing genesis ledgers
    @param json_prefix Prefix for output JSON files
    @return Deferred unit on success
    @raise Exit if daemon fails or export fails
*)
let extract_ledgers config config_file ledger_dir json_prefix =
  Log.Global.info "Starting ledger extraction" ;
  Log.Global.info "Config: %s" config_file ;
  Log.Global.info "Ledger dir: %s" ledger_dir ;
  Log.Global.info "Output prefix: %s" json_prefix ;

  let override_file =
    File_operations.workdir_path config.Types.workdir
      Constants.FileNames.override_genesis_timestamp
  in

  (* Start daemon in background *)
  Log.Global.info "Starting mina daemon in background" ;
  let%bind () =
    Shell_operations.run_command
      ~env:[ (Constants.EnvVars.mina_libp2p_pass, "") ]
      (sprintf
         "%s daemon --libp2p-keypair %s/%s/%s --config-file %s --config-file \
          %s --seed --genesis-ledger-dir %s --log-level %s > /dev/null 2>&1 &"
         config.executables.mina
         (Filename.quote config.workdir)
         Constants.Subdirs.keys Constants.FileNames.p2p_key
         (Filename.quote config_file)
         (Filename.quote override_file)
         (Filename.quote ledger_dir)
         config.mina_log_level )
    |> Deferred.ignore_m
  in

  (* Wait for daemon to be ready and export staged ledger *)
  let rec wait_for_export () =
    Log.Global.debug "Attempting to export staged ledger" ;
    match%bind
      Shell_operations.run_command
        (sprintf
           "%s ledger export staged-ledger | jq . > %s-staged.json 2>/dev/null"
           config.executables.mina
           (Filename.quote json_prefix) )
    with
    | Ok () ->
        Log.Global.info "Successfully exported staged ledger" ;
        return ()
    | Error _ ->
        Log.Global.debug "Daemon not ready yet, waiting 60 seconds" ;
        let%bind () = after Constants.Timeouts.daemon_ready_poll_interval in
        (* Check if daemon is still running *)
        let%bind daemon_running = Shell_operations.is_daemon_running () in
        if not daemon_running then (
          Log.Global.error "Daemon died before exporting ledgers" ;
          eprintf "%s" Constants.Messages.daemon_died ;
          exit 1 )
        else wait_for_export ()
  in

  let%bind () = wait_for_export () in

  (* Export other ledgers *)
  Log.Global.info "Exporting staking epoch ledger" ;
  let%bind () =
    Shell_operations.run_command
      (sprintf "%s ledger export staking-epoch-ledger | jq . > %s-staking.json"
         config.executables.mina
         (Filename.quote json_prefix) )
    |> Deferred.ignore_m
  in

  Log.Global.info "Exporting next epoch ledger" ;
  let%bind () =
    Shell_operations.run_command
      (sprintf "%s ledger export next-epoch-ledger | jq . > %s-next.json"
         config.executables.mina
         (Filename.quote json_prefix) )
    |> Deferred.ignore_m
  in

  (* Stop daemon *)
  Log.Global.info "Stopping mina daemon" ;
  Shell_operations.run_command
    (sprintf "%s client stop" config.executables.mina)
  |> Deferred.ignore_m

(** Perform RocksDB validation for a single ledger tarball.

    Extracts and compares packaged, generated, and web-hosted versions
    of the ledger database.

    @param config Validation configuration
    @param tarname Name of the tarball (without .tar.gz extension)
    @param error Reference to accumulating error count
    @return Deferred unit
*)
let validate_ledger_tarball config tarname error =
  Log.Global.info "Validating ledger tarball: %s" tarname ;

  let tardir =
    sprintf "%s/%s/%s" config.Types.workdir Constants.Subdirs.ledgers tarname
  in
  let workdir = config.workdir in

  (* Create directories *)
  let%bind () =
    Shell_operations.run_command
      (sprintf "mkdir -p %s/{packaged,generated,web}" (Filename.quote tardir))
    |> Deferred.ignore_m
  in

  (* Extract tar files *)
  Log.Global.debug "Extracting generated ledger" ;
  let%bind () =
    Shell_operations.run_command
      (sprintf "tar -xzf %s/%s/%s.tar.gz -C %s/generated"
         (Filename.quote workdir) Constants.Subdirs.ledgers tarname
         (Filename.quote tardir) )
    |> Deferred.ignore_m
  in

  Log.Global.debug "Extracting packaged ledger" ;
  let%bind () =
    Shell_operations.run_command
      (sprintf "tar -xzf %s/%s.tar.gz -C %s/packaged"
         (Filename.quote config.genesis_ledger_dir)
         tarname (Filename.quote tardir) )
    |> Deferred.ignore_m
  in

  (* Download from S3 *)
  Log.Global.debug "Downloading ledger from S3" ;
  let%bind () =
    Shell_operations.run_command
      (sprintf "curl %s/%s.tar.gz | tar -xz -C %s/web"
         config.mina_ledger_s3_bucket tarname (Filename.quote tardir) )
    |> Deferred.ignore_m
  in

  (* Use RocksDB library to scan databases *)
  Log.Global.info "Scanning RocksDB databases" ;
  let%bind packaged_scan_result =
    Rocksdb_utils.scan_rocksdb_to_hex
      (sprintf "%s/packaged" tardir)
      (sprintf "%s/packaged.scan" workdir)
  in
  let%bind web_scan_result =
    Rocksdb_utils.scan_rocksdb_to_hex (sprintf "%s/web" tardir)
      (sprintf "%s/web.scan" workdir)
  in
  let%bind generated_scan_result =
    Rocksdb_utils.scan_rocksdb_to_hex
      (sprintf "%s/generated" tardir)
      (sprintf "%s/generated.scan" workdir)
  in

  (* Check for scan errors *)
  ( match (packaged_scan_result, web_scan_result, generated_scan_result) with
  | Ok (), Ok (), Ok () ->
      ()
  | _ ->
      Log.Global.error "Failed to scan RocksDB for: %s" tarname ;
      eprintf "Error: failed to scan RocksDB for %s\n%!" tarname ;
      error := !error + 1 ) ;

  (* Compare scan results *)
  Log.Global.info "Comparing RocksDB scan results" ;
  let%bind gen_pkg_match =
    File_operations.files_equal
      (sprintf "%s/generated.scan" workdir)
      (sprintf "%s/packaged.scan" workdir)
  in
  let%bind pkg_web_match =
    File_operations.files_equal
      (sprintf "%s/packaged.scan" workdir)
      (sprintf "%s/web.scan" workdir)
  in

  if not (gen_pkg_match && pkg_web_match) then (
    Log.Global.error "RocksDB contents mismatch for: %s" tarname ;
    eprintf "Error: kvdb contents mismatch for %s\n%!" tarname ;
    error := !error + 1 ) ;

  return ()

(** Main validation workflow.

    Orchestrates the complete verification process from setup through
    final validation and comparison.

    @param network_name Network identifier
    @param fork_config Path to fork configuration
    @param workdir Working directory
    @param precomputed_block_prefix_arg Optional GCS prefix override
    @return Deferred unit, exits with code 0 on success or 1 on failure
*)
let main network_name fork_config workdir precomputed_block_prefix_arg =
  Log.Global.info "=== Starting Fork Config Verification ===" ;
  Log.Global.info "Network: %s" network_name ;
  Log.Global.info "Fork config: %s" fork_config ;
  Log.Global.info "Working directory: %s" workdir ;

  (* Build configuration *)
  let%bind config =
    Validation.build_validation_config network_name fork_config workdir
      precomputed_block_prefix_arg
  in

  Log.Global.info "Precomputed block prefix: %s" config.precomputed_block_prefix ;

  (* Create working directories *)
  let%bind () = File_operations.create_workdir_structure workdir in

  (* Extract fork block information *)
  Log.Global.info "Extracting fork block information from config" ;
  let%bind fork_block_state_hash =
    Json_utils.jq_extract fork_config Constants.JsonPaths.ForkConfig.state_hash
  in
  let%bind fork_block_length =
    Json_utils.jq_extract fork_config
      Constants.JsonPaths.ForkConfig.blockchain_length
  in
  Log.Global.info "Fork block - state hash: %s, length: %s"
    fork_block_state_hash fork_block_length ;

  (* Obtain precomputed fork block *)
  let%bind () =
    Validation.obtain_precomputed_fork_block config ~fork_block_state_hash
      ~fork_block_length
  in

  (* Generate libp2p keypair *)
  let%bind () = Validation.ensure_libp2p_keypair config in

  (* Generate genesis ledgers *)
  eprintf "%s" Constants.Messages.generating_genesis_ledgers ;
  Log.Global.info "Starting genesis ledger generation process" ;

  (* Copy and patch config *)
  Log.Global.info "Copying fork config to working directory" ;
  let%bind () =
    File_operations.copy_file ~src:fork_config
      ~dst:
        (File_operations.workdir_path workdir Constants.FileNames.config_orig)
  in

  Log.Global.info "Patching config to remove ledger metadata" ;
  let%bind () =
    Shell_operations.run_command
      (sprintf "jq 'del(.ledger.num_accounts) | del(.ledger.name)' %s > %s"
         (Filename.quote
            (File_operations.workdir_path workdir
               Constants.FileNames.config_orig ) )
         (Filename.quote
            (File_operations.workdir_path workdir Constants.FileNames.config) ) )
    |> Deferred.ignore_m
  in

  (* Generate legacy ledgers *)
  let%bind () = Validation.generate_legacy_ledgers config in

  (* Verify hashes match precomputed block *)
  Log.Global.info "Verifying legacy hashes match precomputed block" ;
  let%bind hashes_match =
    Json_utils.verify_legacy_hashes_match
      ~legacy_hashes_file:
        (File_operations.workdir_path workdir Constants.FileNames.legacy_hashes)
      ~precomputed_block_file:
        (File_operations.workdir_path workdir
           Constants.FileNames.precomputed_fork_block )
  in

  let%bind () =
    if hashes_match then (
      Log.Global.info "Hash verification successful" ;
      return () )
    else (
      Log.Global.error "Hash verification failed" ;
      eprintf
        "Hashes in config %s don't match hashes from the precomputed block\n%!"
        fork_config ;
      exit 1 )
  in

  (* Generate new ledgers *)
  let%bind () = Validation.generate_new_ledgers config in

  (* Extract genesis timestamp from packaged config *)
  Log.Global.info "Extracting genesis timestamp from packaged config" ;
  let%bind genesis_timestamp =
    Json_utils.jq_extract config.packaged_daemon_config
      Constants.JsonPaths.DaemonConfig.genesis_timestamp
  in
  Log.Global.info "Genesis timestamp: %s" genesis_timestamp ;

  (* Create substituted config *)
  Log.Global.info "Creating runtime config with substituted values" ;
  let%bind () =
    let env =
      [ ("FORK_CONFIG_JSON", fork_config)
      ; ( "LEDGER_HASHES_JSON"
        , File_operations.workdir_path workdir Constants.FileNames.hashes )
      ; ("GENESIS_TIMESTAMP", genesis_timestamp)
      ; ("SECONDS_PER_SLOT", config.seconds_per_slot)
      ; ("FORKING_FROM_CONFIG_JSON", config.forking_from_config_json)
      ]
    in
    Shell_operations.run_command ~env
      (sprintf "%s > %s" config.executables.create_runtime_config
         (Filename.quote
            (File_operations.workdir_path workdir
               Constants.FileNames.config_substituted ) ) )
    |> Deferred.ignore_m
  in

  (* Create genesis timestamp override *)
  eprintf "%s" Constants.Messages.exporting_ledgers ;
  Log.Global.info "Starting ledger export process from running nodes" ;

  Log.Global.info "Creating genesis timestamp override file" ;
  let%bind override_content = Json_utils.create_genesis_timestamp_override () in
  let%bind () =
    Writer.save
      (File_operations.workdir_path workdir
         Constants.FileNames.override_genesis_timestamp )
      ~contents:override_content
  in

  (* Move existing tar.gz files to backup *)
  let%bind () =
    File_operations.move_tar_gz_files ~src_dir:config.genesis_ledger_dir
      ~dst_dir:
        (File_operations.workdir_path workdir Constants.Subdirs.ledgers_backup)
  in

  (* Extract ledgers (with download test if not disabled) *)
  let%bind () =
    if config.test_ledger_download then
      let%bind () =
        extract_ledgers config config.packaged_daemon_config
          (File_operations.workdir_path workdir
             Constants.Subdirs.ledgers_downloaded )
          (File_operations.workdir_path workdir "downloaded")
      in
      Shell_operations.run_command
        "rm -Rf /tmp/coda_cache_dir/*.tar.gz /tmp/s3_cache_dir/*.tar.gz"
      |> Deferred.ignore_m
    else return ()
  in

  (* Extract reference ledgers *)
  let%bind () =
    extract_ledgers config
      (File_operations.workdir_path workdir
         Constants.FileNames.config_substituted )
      (File_operations.workdir_path workdir Constants.Subdirs.ledgers)
      (File_operations.workdir_path workdir "reference")
  in

  (* Move tar.gz files back *)
  let%bind () =
    File_operations.move_tar_gz_files
      ~src_dir:
        (File_operations.workdir_path workdir Constants.Subdirs.ledgers_backup)
      ~dst_dir:config.genesis_ledger_dir
  in

  (* Extract packaged ledgers *)
  let%bind () =
    extract_ledgers config config.packaged_daemon_config
      config.genesis_ledger_dir
      (File_operations.workdir_path workdir "packaged")
  in

  (* Final comparisons *)
  eprintf "%s" Constants.Messages.performing_final_comparisons ;
  Log.Global.info "Starting final comparison phase" ;

  (* Compare config hashes *)
  let%bind config_hashes_match =
    Json_utils.verify_config_hashes_match
      ~config1_file:
        (File_operations.workdir_path workdir
           Constants.FileNames.config_substituted )
      ~config2_file:config.packaged_daemon_config
  in

  let error = ref 0 in
  if not config_hashes_match then (
    Log.Global.error "Packaged config hashes not expected" ;
    eprintf "Packaged config hashes in %s not expected compared to %s/%s\n%!"
      config.packaged_daemon_config workdir
      Constants.FileNames.config_substituted ;
    error := 1 ) ;

  (* Compare packaged JSON files *)
  let%bind packaged_files =
    Shell_operations.run_command_capture
      (sprintf "ls %s/packaged-*.json" (Filename.quote workdir))
  in
  let%bind () =
    match packaged_files with
    | Ok files_str ->
        let files = String.split_lines files_str in
        Deferred.List.iter files ~f:(fun file ->
            let basename = Filename.basename file in
            let name =
              String.chop_suffix_exn ~suffix:".json" basename
              |> fun s -> String.chop_prefix_exn ~prefix:"packaged-" s
            in
            let reference_file = sprintf "%s/reference-%s.json" workdir name in
            let%bind match_ref =
              File_operations.files_equal file reference_file
            in
            if not match_ref then (
              Log.Global.error "File %s does not match reference" file ;
              eprintf "Error: %s does not match reference\n%!" file ;
              error := !error + 1 ) ;

            if config.test_ledger_download then (
              let downloaded_file =
                sprintf "%s/downloaded-%s.json" workdir name
              in
              let%bind match_dl =
                File_operations.files_equal file downloaded_file
              in
              if not match_dl then (
                Log.Global.error "File %s does not match downloaded" file ;
                eprintf "Error: %s does not match downloaded\n%!" file ;
                error := !error + 1 ) ;
              return () )
            else return () )
    | Error _ ->
        return ()
  in

  (* Compare RocksDB contents *)
  let%bind ledger_tars =
    Shell_operations.run_command_capture
      (sprintf "ls %s/%s/*.tar.gz" (Filename.quote workdir)
         Constants.Subdirs.ledgers )
  in
  let%bind () =
    match ledger_tars with
    | Ok files_str ->
        let files = String.split_lines files_str in
        Deferred.List.iter files ~f:(fun file ->
            let tarname =
              Filename.basename file
              |> fun s -> String.chop_suffix_exn ~suffix:".tar.gz" s
            in
            validate_ledger_tarball config tarname error )
    | Error _ ->
        return ()
  in

  (* Final result *)
  if !error <> 0 then (
    Log.Global.error "Validation failed with %d errors" !error ;
    eprintf "%s" Constants.Messages.validation_failed ;
    exit 1 )
  else (
    Log.Global.info "All validations passed successfully" ;
    eprintf "%s" Constants.Messages.validation_successful ;
    exit 0 )

(** Application entry point with CLI argument parsing. *)
let () =
  (* Setup logging *)
  Log.Global.set_level `Info ;
  Log.Global.set_output [ Log.Output.stderr () ] ;

  Command.run
    (Command.async
       ~summary:
         "Verify that an installed package is correct according to an exported \
          fork_config.json file"
       ~readme:(fun () ->
         {|This app validates an installed package against a fork_config.json file.

ENVIRONMENT VARIABLES:
- MINA_EXE (default: mina or ./_build/default/src/app/cli/src/mina.exe)
- MINA_GENESIS_EXE (default: mina-create-genesis or ./_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe)
- MINA_LEGACY_GENESIS_EXE (default: mina-create-legacy-genesis or ./runtime_genesis_ledger_of_mainnet.exe)
- PACKAGED_DAEMON_CONFIG (default: /var/lib/coda/config_*.json)
- CREATE_RUNTIME_CONFIG (default: mina-hf-create-runtime-config or ./scripts/hardfork/create_runtime_config.sh)
- GENESIS_LEDGER_DIR (default: /var/lib/coda)
- FORKING_FROM_CONFIG_JSON (default: /var/lib/coda/mainnet.json or genesis_ledgers/mainnet.json)
- SECONDS_PER_SLOT (default: 180)
- PRECOMPUTED_FORK_BLOCK (default: fetches with gsutil)
- GSUTIL (default: gsutil)
- MINA_LOG_LEVEL (default: info)
- MINA_LEDGER_S3_BUCKET (default: https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net)
- NO_TEST_LEDGER_DOWNLOAD (if set, skips ledger download test)

VALIDATION:
- Verifies accounts in config.json match PACKAGED_DAEMON_CONFIG
- Ensures genesis ledger directory tarfile contents match reference copies
- Takes >20min due to rehashing requirements

EXIT CODES:
- 0: Validation successful
- 1: Validation failed

For detailed documentation, see README.md|}
         )
       (let%map_open.Command network_name =
          flag "--network-name" (required string)
            ~doc:"STRING The network name (e.g., mainnet, devnet)"
        and fork_config =
          flag "--fork-config" (required string)
            ~doc:
              "FILE Path to the exported fork_config.json file with all \
               accounts"
        and workdir =
          flag "--working-dir" (required string)
            ~doc:"DIR Working directory where ledgers/configs will be created"
        and precomputed_block_prefix =
          flag "--precomputed-block-prefix" (optional string)
            ~doc:
              "STRING Optional prefix for precomputed block (default: \
               gs://mina_network_block_data/<network-name>)"
        in
        fun () -> main network_name fork_config workdir precomputed_block_prefix
       ) )
