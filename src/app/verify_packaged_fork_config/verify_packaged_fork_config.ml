(* verify_packaged_fork_config.ml -- OCaml version of the bash script *)

open Core
open Async


(* Helper function to find an executable in PATH or use a fallback *)
let source_build_fallback cmd_name fallback_path =
  Log.Global.info "Looking for executable: %s (fallback: %s)" cmd_name fallback_path;
  match%bind Unix.system (sprintf "command -v %s > /dev/null 2>&1" cmd_name) with
  | Ok () ->
      Log.Global.info "Found %s in PATH" cmd_name;
      return cmd_name
  | Error _ -> (
      Log.Global.info "Command %s not found in PATH, checking fallback path" cmd_name;
      match%bind Sys.file_exists fallback_path with
      | `Yes ->
          Log.Global.info "Found fallback executable at %s" fallback_path;
          return fallback_path
      | `No | `Unknown ->
          Log.Global.error "Error: program not found in PATH (as %s) or relative to cwd (as %s)" cmd_name fallback_path;
          eprintf
            "Error: program not found in PATH (as %s) or relative to cwd (as \
             %s)\n\
             %!"
            cmd_name fallback_path ;
          exit 1 )

(* RocksDB scanning function that replaces ldb command *)
let scan_rocksdb_to_hex db_path output_file =
  Log.Global.info "Scanning RocksDB at %s to output file %s" db_path output_file;
  let open Rocksdb.Database in
  try
    let db = create db_path in
    let alist = to_alist db in
    let%bind oc = Writer.open_file output_file in
    List.iter alist ~f:(fun (key, value) ->
        let key_hex =
          Bigstring.to_string key
          |> String.to_list
          |> List.map ~f:(fun c -> sprintf "%02x" (Char.to_int c))
          |> String.concat ~sep:""
        in
        let value_hex =
          Bigstring.to_string value
          |> String.to_list
          |> List.map ~f:(fun c -> sprintf "%02x" (Char.to_int c))
          |> String.concat ~sep:""
        in
        Writer.write oc (sprintf "%s : %s\n" key_hex value_hex) ) ;
    close db ;
    let%bind () = Writer.close oc in
    return (Ok ())
  with exn -> return (Error (Exn.to_string exn))

(* Run a shell command and return exit status *)
let run_command ?(env = []) cmd =
  let env_vars =
    if List.is_empty env then ""
    else (List.map env ~f:(fun (k, v) -> sprintf "%s=%s" k v) |> String.concat ~sep:" ") ^ " "
  in
  let full_cmd = env_vars ^ cmd in
  Log.Global.info "Executing command: %s" full_cmd;
  match%map Unix.system full_cmd with
  | Ok () ->
      Log.Global.info "Command completed successfully: %s" full_cmd;
      Ok ()
  | Error err ->
      Log.Global.error "Command failed: %s (error: %s)" full_cmd (Unix.Exit_or_signal.to_string_hum (Error err));
      Error (Unix.Exit_or_signal.to_string_hum (Error err))

(* Run a shell command and capture stdout *)
let run_command_capture cmd =
  Log.Global.info "Executing command and capturing output: %s" cmd;
  let%bind result = Process.run_lines ~prog:"bash" ~args:[ "-c"; cmd ] () in
  match result with
  | Ok output ->
      Log.Global.info "Command output captured successfully (lines: %d)" (List.length output);
      return (Or_error.map result ~f:(String.concat ~sep:"\n"))
  | Error err ->
      Log.Global.error "Command failed to capture output: %s (error: %s)" cmd (Error.to_string_hum err);
      return (Or_error.map result ~f:(String.concat ~sep:"\n"))

(* Extract a JSON field using jq *)
let jq_extract file_path query =
  let cmd = sprintf "jq -r '%s' %s" query (Filename.quote file_path) in
  Log.Global.info "Extracting JSON field with query '%s' from file %s" query file_path;
  match%bind run_command_capture cmd with
  | Ok value ->
      Log.Global.info "JSON extraction successful, value: %s" value;
      return value
  | Error err ->
      Log.Global.error "JSON extraction failed: %s" (Error.to_string_hum err);
      eprintf "Error extracting JSON: %s\n%!" (Error.to_string_hum err) ;
      exit 1

(* Compare two files *)
let files_equal file1 file2 =
  let cmd = sprintf "cmp -s %s %s" (Filename.quote file1) (Filename.quote file2) in
  Log.Global.info "Comparing files: %s vs %s" file1 file2;
  match%map Unix.system cmd with
  | Ok () ->
      Log.Global.info "Files are identical: %s = %s" file1 file2;
      true
  | Error _ ->
      Log.Global.info "Files differ: %s ≠ %s" file1 file2;
      false

let main network_name fork_config workdir precomputed_block_prefix_arg =
  Log.Global.info "Starting verification process";
  Log.Global.info "Network name: %s" network_name;
  Log.Global.info "Fork config: %s" fork_config;
  Log.Global.info "Working directory: %s" workdir;
  Log.Global.info "Precomputed block prefix: %s" (Option.value precomputed_block_prefix_arg ~default:"(default)");
  
  Log.Global.info "Resolving executable paths";
  let%bind mina_exe =
    match Sys.getenv "MINA_EXE" with
    | Some exe ->
        Log.Global.info "Using MINA_EXE from environment: %s" exe;
        return exe
    | None ->
        Log.Global.info "MINA_EXE not set, searching for mina executable";
        source_build_fallback "mina" "./_build/default/src/app/cli/src/mina.exe"
  in
  let%bind mina_genesis_exe =
    match Sys.getenv "MINA_GENESIS_EXE" with
    | Some exe ->
        Log.Global.info "Using MINA_GENESIS_EXE from environment: %s" exe;
        return exe
    | None ->
        Log.Global.info "MINA_GENESIS_EXE not set, searching for mina-create-genesis";
        source_build_fallback "mina-create-genesis"
          "./_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe"
  in
  let%bind mina_legacy_genesis_exe =
    match Sys.getenv "MINA_LEGACY_GENESIS_EXE" with
    | Some exe ->
        Log.Global.info "Using MINA_LEGACY_GENESIS_EXE from environment: %s" exe;
        return exe
    | None ->
        Log.Global.info "MINA_LEGACY_GENESIS_EXE not set, searching for mina-create-legacy-genesis";
        source_build_fallback "mina-create-legacy-genesis"
          "./runtime_genesis_ledger_of_mainnet.exe"
  in
  let%bind create_runtime_config =
    match Sys.getenv "CREATE_RUNTIME_CONFIG" with
    | Some exe ->
        Log.Global.info "Using CREATE_RUNTIME_CONFIG from environment: %s" exe;
        return exe
    | None ->
        Log.Global.info "CREATE_RUNTIME_CONFIG not set, searching for mina-hf-create-runtime-config";
        source_build_fallback "mina-hf-create-runtime-config"
          "./scripts/hardfork/create_runtime_config.sh"
  in
  Log.Global.info "Checking for gsutil availability";
  let%bind gsutil =
    match Sys.getenv "GSUTIL" with
    | Some exe ->
        Log.Global.info "Using GSUTIL from environment: %s" exe;
        return exe
    | None ->
        Log.Global.info "GSUTIL not set, searching in PATH";
        match%bind run_command_capture "command -v gsutil || echo ''" with
        | Ok path ->
            let stripped_path = String.strip path in
            Log.Global.info "Found gsutil at: %s" stripped_path;
            return stripped_path
        | Error _ ->
            Log.Global.info "gsutil not found";
            return ""
  in
  (* Check if PRECOMPUTED_FORK_BLOCK exists or gsutil is available *)
  Log.Global.info "Validating precomputed fork block availability";
  let precomputed_fork_block = Sys.getenv "PRECOMPUTED_FORK_BLOCK" in
  let%bind () =
    match precomputed_fork_block with
    | Some path ->
        Log.Global.info "PRECOMPUTED_FORK_BLOCK set to: %s" path;
        let%bind file_exists = Sys.file_exists path in
        (match file_exists with
        | `Yes ->
            Log.Global.info "Precomputed fork block exists";
            return ()
        | `No | `Unknown ->
            if String.is_empty gsutil then (
              Log.Global.error "gsutil is required when PRECOMPUTED_FORK_BLOCK is nonexistent path";
              eprintf
                "Error: gsutil is required when PRECOMPUTED_FORK_BLOCK is \
                 nonexistent path\n\
                 %!" ;
              exit 1 )
            else return ())
    | None ->
        Log.Global.info "PRECOMPUTED_FORK_BLOCK not set, will fetch with gsutil";
        return ()
  in
  (* Find packaged daemon config *)
  Log.Global.info "Locating packaged daemon config";
  let%bind installed_config =
    run_command_capture "echo /var/lib/coda/config_*.json"
  in
  let packaged_daemon_config =
    match Sys.getenv "PACKAGED_DAEMON_CONFIG" with
    | Some path ->
        Log.Global.info "Using PACKAGED_DAEMON_CONFIG from environment: %s" path;
        path
    | None -> (
        Log.Global.info "PACKAGED_DAEMON_CONFIG not set, using discovered config";
        match installed_config with
        | Ok path ->
            let stripped_path = String.strip path in
            Log.Global.info "Found config at: %s" stripped_path;
            stripped_path
        | Error _ ->
            Log.Global.error "No config found";
            "" )
  in
  let%bind () =
    Log.Global.info "Verifying packaged daemon config exists: %s" packaged_daemon_config;
    match%bind Sys.file_exists packaged_daemon_config with
    | `Yes ->
        Log.Global.info "Packaged daemon config found";
        return ()
    | `No | `Unknown ->
        Log.Global.error "Packaged daemon config not found: %s" packaged_daemon_config;
        eprintf
          "Error: set PACKAGED_DAEMON_CONFIG to the path to the JSON file to \
           verify\n\
           %!" ;
        exit 1
  in
  let genesis_ledger_dir =
    match Sys.getenv "GENESIS_LEDGER_DIR" with
    | Some dir ->
        Log.Global.info "Using GENESIS_LEDGER_DIR from environment: %s" dir;
        dir
    | None ->
        Log.Global.info "Using default GENESIS_LEDGER_DIR: /var/lib/coda";
        "/var/lib/coda"
  in
  let seconds_per_slot =
    match Sys.getenv "SECONDS_PER_SLOT" with
    | Some s ->
        Log.Global.info "Using SECONDS_PER_SLOT from environment: %s" s;
        s
    | None ->
        Log.Global.info "Using default SECONDS_PER_SLOT: 180";
        "180"
  in
  let%bind forking_from_config_json =
    match Sys.getenv "FORKING_FROM_CONFIG_JSON" with
    | Some path ->
        Log.Global.info "Using FORKING_FROM_CONFIG_JSON from environment: %s" path;
        return path
    | None ->
        Log.Global.info "FORKING_FROM_CONFIG_JSON not set, searching for mainnet.json";
        source_build_fallback "/var/lib/coda/mainnet.json"
          "genesis_ledgers/mainnet.json"
  in
  (* Create working directories *)
  Log.Global.info "Creating working directories in %s" workdir;
  let%bind () =
    run_command
      (sprintf "mkdir -p %s/{ledgers{,-backup},keys}"
         (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  Log.Global.info "Setting permissions for keys directory";
  let%bind () =
    run_command (sprintf "chmod 700 %s/keys" (Filename.quote workdir))
    |> Deferred.ignore_m
  in
  (* Extract fork block information *)
  Log.Global.info "Extracting fork block information from config";
  let%bind fork_block_state_hash = jq_extract fork_config ".proof.fork.state_hash" in
  let%bind fork_block_length = jq_extract fork_config ".proof.fork.blockchain_length" in
  Log.Global.info "Fork block - state hash: %s, length: %s" fork_block_state_hash fork_block_length;
  
  (* Put the fork block where we want it *)
  Log.Global.info "Obtaining precomputed fork block";
  let%bind () =
    match precomputed_fork_block with
    | Some path -> (
        Log.Global.info "Checking if precomputed fork block exists at: %s" path;
        match%bind Sys.file_exists path with
        | `Yes ->
            Log.Global.info "Copying precomputed fork block from %s" path;
            run_command
              (sprintf "cp %s %s/precomputed_fork_block.json"
                 (Filename.quote path) (Filename.quote workdir) )
            |> Deferred.ignore_m
        | `No | `Unknown ->
            Log.Global.info "Precomputed fork block not found locally, downloading from GCS";
            let prefix =
              match precomputed_block_prefix_arg with
              | Some p ->
                  p
              | None ->
                  sprintf "gs://mina_network_block_data/%s" network_name
            in
            let block_path =
              sprintf "%s-%s-%s.json" prefix fork_block_length fork_block_state_hash
            in
            run_command
              (sprintf "%s cp %s %s/precomputed_fork_block.json" gsutil
                 (Filename.quote block_path) (Filename.quote workdir) )
            |> Deferred.ignore_m )
    | None ->
        Log.Global.info "Downloading precomputed fork block from GCS";
        let prefix =
          match precomputed_block_prefix_arg with
          | Some p ->
              p
          | None ->
              sprintf "gs://mina_network_block_data/%s" network_name
        in
        let block_path =
          sprintf "%s-%s-%s.json" prefix fork_block_length fork_block_state_hash
        in
        run_command
          (sprintf "%s cp %s %s/precomputed_fork_block.json" gsutil
             (Filename.quote block_path) (Filename.quote workdir) )
        |> Deferred.ignore_m
  in
  (* Generate libp2p keypair if needed *)
  let p2p_key_path = sprintf "%s/keys/p2p" workdir in
  Log.Global.info "Checking for libp2p keypair at %s" p2p_key_path;
  let%bind () =
    match%bind Sys.file_exists p2p_key_path with
    | `Yes ->
        Log.Global.info "libp2p keypair already exists";
        return ()
    | `No | `Unknown ->
        Log.Global.info "Generating new libp2p keypair";
        run_command
          ~env:[ ("MINA_LIBP2P_PASS", "") ]
          (sprintf "%s libp2p generate-keypair --privkey-path %s" mina_exe
             (Filename.quote p2p_key_path) )
        |> Deferred.ignore_m
  in
  eprintf "generating genesis ledgers ... (this may take a while)\n%!" ;
  Log.Global.info "Starting genesis ledger generation process";
  
  (* Copy and patch config *)
  Log.Global.info "Copying fork config to working directory";
  let%bind () =
    run_command
      (sprintf "cp %s %s/config_orig.json" (Filename.quote fork_config)
         (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  Log.Global.info "Patching config to remove ledger metadata";
  let%bind () =
    run_command
      (sprintf
         "jq 'del(.ledger.num_accounts) | del(.ledger.name)' \
          %s/config_orig.json > %s/config.json"
         (Filename.quote workdir) (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  (* Generate legacy ledgers *)
  Log.Global.info "Generating legacy ledgers";
  let%bind () =
    run_command
      (sprintf
         "%s --config-file %s/config.json --genesis-dir %s/legacy_ledgers \
          --hash-output-file %s/legacy_hashes.json"
         mina_legacy_genesis_exe (Filename.quote workdir)
         (Filename.quote workdir) (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  (* Verify hashes match precomputed block *)
  Log.Global.info "Verifying legacy hashes match precomputed block";
  let%bind result =
    run_command_capture
      (sprintf
         "jq --slurpfile block %s/precomputed_fork_block.json --slurpfile \
          legacy_hashes %s/legacy_hashes.json -n \
          '($legacy_hashes[0].epoch_data.staking.hash == \
          $block[0].data.protocol_state.body.consensus_state.staking_epoch_data.ledger.hash \
          and $legacy_hashes[0].epoch_data.next.hash == \
          $block[0].data.protocol_state.body.consensus_state.next_epoch_data.ledger.hash \
          and $legacy_hashes[0].ledger.hash == \
          $block[0].data.protocol_state.body.blockchain_state.staged_ledger_hash.non_snark.ledger_hash)'"
         (Filename.quote workdir) (Filename.quote workdir) )
  in
  let%bind () =
    match result with
    | Ok "true" ->
        Log.Global.info "Hash verification successful - legacy hashes match precomputed block";
        return ()
    | _ ->
        Log.Global.error "Hash verification failed - legacy hashes don't match precomputed block";
        eprintf
          "Hashes in config %s don't match hashes from the precomputed block\n\
           %!"
          fork_config ;
        exit 1
  in
  (* Patch verification key format *)
  Log.Global.info "Patching verification key format in config";
  let%bind () =
    run_command
      (sprintf
         "sed -i -e \
          's/\"set_verification_key\": \
          \"signature\"/\"set_verification_key\": {\"auth\": \"signature\", \
          \"txn_version\": \"2\"}/g' %s/config.json"
         (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  (* Generate new ledgers *)
  Log.Global.info "Generating new ledgers with patched config";
  let%bind () =
    run_command
      (sprintf
         "%s --config-file %s/config.json --genesis-dir %s/ledgers \
          --hash-output-file %s/hashes.json"
         mina_genesis_exe (Filename.quote workdir) (Filename.quote workdir)
         (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  (* Extract genesis timestamp from packaged config *)
  Log.Global.info "Extracting genesis timestamp from packaged config";
  let%bind genesis_timestamp =
    jq_extract packaged_daemon_config ".genesis.genesis_state_timestamp"
  in
  Log.Global.info "Genesis timestamp: %s" genesis_timestamp;
  
  (* Create substituted config *)
  Log.Global.info "Creating runtime config with substituted values";
  let%bind () =
    let env =
      [ ("FORK_CONFIG_JSON", fork_config)
      ; ("LEDGER_HASHES_JSON", sprintf "%s/hashes.json" workdir)
      ; ("GENESIS_TIMESTAMP", genesis_timestamp)
      ; ("SECONDS_PER_SLOT", seconds_per_slot)
      ; ("FORKING_FROM_CONFIG_JSON", forking_from_config_json)
      ]
    in
    run_command ~env
      (sprintf "%s > %s/config-substituted.json" create_runtime_config
         (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  eprintf "exporting ledgers from running node ... (this may take a while)\n%!" ;
  Log.Global.info "Starting ledger export process from running nodes";
  
  (* Create override file *)
  Log.Global.info "Creating genesis timestamp override file";
  let%bind () =
    run_command
      (sprintf
         "echo '{\"genesis\":{\"genesis_state_timestamp\":\"'$(date -u \
          +\"%%Y-%%m-%%dT%%H:%%M:%%SZ\")'\"}}' > %s/override-genesis-timestamp.json"
         (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  (* Extract ledgers function *)
  let extract_ledgers config_file ledger_dir json_prefix =
    Log.Global.info "Starting ledger extraction with config: %s, ledger_dir: %s, prefix: %s" config_file ledger_dir json_prefix;
    let override_file = sprintf "%s/override-genesis-timestamp.json" workdir in
    let mina_log_level =
      match Sys.getenv "MINA_LOG_LEVEL" with
      | Some level ->
          Log.Global.info "Using MINA_LOG_LEVEL from environment: %s" level;
          level
      | None ->
          Log.Global.info "Using default MINA_LOG_LEVEL: info";
          "info"
    in
    (* Start daemon in background *)
    Log.Global.info "Starting mina daemon in background";
    let%bind () =
      run_command
        ~env:[ ("MINA_LIBP2P_PASS", "") ]
        (sprintf
           "%s daemon --libp2p-keypair %s/keys/p2p --config-file %s \
            --config-file %s --seed --genesis-ledger-dir %s --log-level %s > \
            /dev/null 2>&1 &"
           mina_exe (Filename.quote workdir) (Filename.quote config_file)
           (Filename.quote override_file) (Filename.quote ledger_dir)
           mina_log_level )
      |> Deferred.ignore_m
    in
    (* Wait for daemon to be ready and export staged ledger *)
    let rec wait_for_export () =
      Log.Global.info "Attempting to export staged ledger";
      match%bind
        run_command
          (sprintf "%s ledger export staged-ledger | jq . > %s-staged.json 2>/dev/null"
             mina_exe (Filename.quote json_prefix) )
      with
      | Ok () ->
          Log.Global.info "Successfully exported staged ledger";
          return ()
      | Error _ ->
          Log.Global.info "Daemon not ready yet, waiting 60 seconds";
          let%bind () = after (Time.Span.of_sec 60.0) in
          (* Check if daemon is still running *)
          Log.Global.info "Checking if daemon is still running";
          let%bind daemon_pid =
            run_command_capture "cat ~/.mina-config/.mina-lock 2>/dev/null || echo ''"
          in
          let%bind daemon_running =
            match daemon_pid with
            | Ok pid_str ->
                let pid = String.strip pid_str in
                if String.is_empty pid then
                  return false
                else (
                  Log.Global.info "Checking if daemon process %s is still running" pid;
                  match%map run_command (sprintf "kill -0 %s 2>/dev/null" pid) with
                  | Ok () -> true
                  | Error _ -> false
                )
            | Error _ ->
                return false
          in
          if not daemon_running then (
            eprintf "daemon died before exporting ledgers\n%!" ;
            exit 1 )
          else wait_for_export ()
    in
    let%bind () = wait_for_export () in
    (* Export other ledgers *)
    Log.Global.info "Exporting staking epoch ledger";
    let%bind () =
      run_command
        (sprintf "%s ledger export staking-epoch-ledger | jq . > %s-staking.json"
           mina_exe (Filename.quote json_prefix) )
      |> Deferred.ignore_m
    in
    Log.Global.info "Exporting next epoch ledger";
    let%bind () =
      run_command
        (sprintf "%s ledger export next-epoch-ledger | jq . > %s-next.json"
           mina_exe (Filename.quote json_prefix) )
      |> Deferred.ignore_m
    in
    (* Stop daemon *)
    Log.Global.info "Stopping mina daemon";
    run_command (sprintf "%s client stop" mina_exe) |> Deferred.ignore_m
  in
  
  (* Create ledgers-downloaded directory *)
  let%bind () =
    run_command (sprintf "mkdir -p %s/ledgers-downloaded" (Filename.quote workdir))
    |> Deferred.ignore_m
  in
  (* Move existing tar.gz files to backup *)
  let%bind () =
    run_command
      (sprintf "mv -t %s/ledgers-backup %s/*.tar.gz 2>/dev/null || true"
         (Filename.quote workdir) (Filename.quote genesis_ledger_dir) )
    |> Deferred.ignore_m
  in
  (* Extract ledgers (with download test if not disabled) *)
  let no_test_ledger_download = Sys.getenv "NO_TEST_LEDGER_DOWNLOAD" in
  let%bind () =
    match no_test_ledger_download with
    | None ->
        let%bind () =
          extract_ledgers packaged_daemon_config
            (sprintf "%s/ledgers-downloaded" workdir)
            (sprintf "%s/downloaded" workdir)
        in
        run_command
          "rm -Rf /tmp/coda_cache_dir/*.tar.gz /tmp/s3_cache_dir/*.tar.gz"
        |> Deferred.ignore_m
    | Some _ ->
        return ()
  in
  (* Extract reference ledgers *)
  let%bind () =
    extract_ledgers
      (sprintf "%s/config-substituted.json" workdir)
      (sprintf "%s/ledgers" workdir)
      (sprintf "%s/reference" workdir)
  in
  (* Move tar.gz files back *)
  let%bind () =
    run_command
      (sprintf "mv -t %s %s/ledgers-backup/* 2>/dev/null || true"
         (Filename.quote genesis_ledger_dir) (Filename.quote workdir) )
    |> Deferred.ignore_m
  in
  (* Extract packaged ledgers *)
  let%bind () =
    extract_ledgers packaged_daemon_config genesis_ledger_dir
      (sprintf "%s/packaged" workdir)
  in
  eprintf "Performing final comparisons...\n%!" ;
  Log.Global.info "Starting final comparison phase";
  (* Compare config hashes *)
  let%bind config_hash_result =
    run_command_capture
      (sprintf
         "jq --slurpfile a %s/config-substituted.json --slurpfile b %s -n \
          '($a[0].epoch_data.staking.hash == $b[0].epoch_data.staking.hash \
          and $a[0].epoch_data.next.hash == $b[0].epoch_data.next.hash and \
          $a[0].ledger.hash == $b[0].ledger.hash)'"
         (Filename.quote workdir) (Filename.quote packaged_daemon_config) )
  in
  let error = ref 0 in
  let () =
    match config_hash_result with
    | Ok "true" ->
        ()
    | _ ->
        Log.Global.error "Packaged config hashes in %s not expected compared to %s/config-substituted.json" packaged_daemon_config workdir;
        eprintf
          "Packaged config hashes in %s not expected compared to \
           %s/config-substituted.json\n\
           %!"
          packaged_daemon_config workdir ;
        error := 1
  in
  (* Compare packaged JSON files *)
  let%bind packaged_files =
    run_command_capture (sprintf "ls %s/packaged-*.json" (Filename.quote workdir))
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
            let%bind match_ref = files_equal file reference_file in
            let () =
              if not match_ref then (
                eprintf "Error: %s does not match reference\n%!" file ;
                error := 1 )
            in
            match no_test_ledger_download with
            | None ->
                let downloaded_file = sprintf "%s/downloaded-%s.json" workdir name in
                let%bind match_dl = files_equal file downloaded_file in
                if not match_dl then (
                  eprintf "Error: %s does not match downloaded\n%!" file ;
                  error := 1 ) ;
                return ()
            | Some _ ->
                return () )
    | Error _ ->
        return ()
  in
  (* Compare RocksDB contents using OCaml library *)
  let%bind ledger_tars =
    run_command_capture (sprintf "ls %s/ledgers/*.tar.gz" (Filename.quote workdir))
  in
  let%bind () =
    match ledger_tars with
    | Ok files_str ->
        let files = String.split_lines files_str in
        Deferred.List.iter files ~f:(fun file ->
            let tarname =
              Filename.basename file |> fun s -> String.chop_suffix_exn ~suffix:".tar.gz" s
            in
            let tardir = sprintf "%s/ledgers/%s" workdir tarname in
            (* Create directories *)
            let%bind () =
              run_command
                (sprintf "mkdir -p %s/{packaged,generated,web}"
                   (Filename.quote tardir) )
              |> Deferred.ignore_m
            in
            (* Extract tar files *)
            let%bind () =
              run_command
                (sprintf "tar -xzf %s -C %s/generated" (Filename.quote file)
                   (Filename.quote tardir) )
              |> Deferred.ignore_m
            in
            let%bind () =
              run_command
                (sprintf "tar -xzf %s/%s.tar.gz -C %s/packaged"
                   (Filename.quote genesis_ledger_dir) tarname
                   (Filename.quote tardir) )
              |> Deferred.ignore_m
            in
            (* Download from S3 *)
            let base_s3_url =
              match Sys.getenv "MINA_LEDGER_S3_BUCKET" with
              | Some url ->
                  url
              | None ->
                  "https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net"
            in
            let%bind () =
              run_command
                (sprintf "curl %s/%s.tar.gz | tar -xz -C %s/web" base_s3_url
                   tarname (Filename.quote tardir) )
              |> Deferred.ignore_m
            in
            (* Use RocksDB library to scan databases *)
            let%bind packaged_scan_result =
              scan_rocksdb_to_hex
                (sprintf "%s/packaged" tardir)
                (sprintf "%s/packaged.scan" workdir)
            in
            let%bind web_scan_result =
              scan_rocksdb_to_hex (sprintf "%s/web" tardir)
                (sprintf "%s/web.scan" workdir)
            in
            let%bind generated_scan_result =
              scan_rocksdb_to_hex
                (sprintf "%s/generated" tardir)
                (sprintf "%s/generated.scan" workdir)
            in
            (* Check for errors *)
            let () =
              match (packaged_scan_result, web_scan_result, generated_scan_result) with
              | Ok (), Ok (), Ok () ->
                  ()
              | _ ->
                  eprintf "Error: failed to scan RocksDB for %s\n%!" tarname ;
                  error := 1
            in
            (* Compare scan results *)
            let%bind gen_pkg_match =
              files_equal
                (sprintf "%s/generated.scan" workdir)
                (sprintf "%s/packaged.scan" workdir)
            in
            let%bind pkg_web_match =
              files_equal
                (sprintf "%s/packaged.scan" workdir)
                (sprintf "%s/web.scan" workdir)
            in
            if not (gen_pkg_match && pkg_web_match) then (
              eprintf "Error: kvdb contents mismatch for %s\n%!" tarname ;
              error := 1 ) ;
            return () )
    | Error _ ->
        return ()
  in
  if !error <> 0 then (
    Log.Global.error "Validation failed with %d errors" !error;
    eprintf "Error: failed validation\n%!" ;
    exit 1 )
  else (
    Log.Global.info "All validations passed successfully";
    eprintf "Validation successful\n%!" ;
    exit 0 )

let () =
  (* Setup logging *)
  Log.Global.set_level `Info;
  Log.Global.set_output [Log.Output.stderr ()];
  Log.Global.info "Starting verify_packaged_fork_config application";
  
  Command.run
    (Command.async 
       ~summary:"Verify that an installed package is correct according to an exported fork_config.json file"
       ~readme:(fun () -> 
         {|This script validates an installed package against a fork_config.json file.

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
- 1: Validation failed|})
       (let%map_open.Command
          network_name = 
            flag "--network-name" (required string) 
              ~doc:"STRING The network name (e.g., mainnet, devnet)"
        and fork_config = 
            flag "--fork-config" (required string)
              ~doc:"FILE Path to the exported fork_config.json file with all accounts"
        and workdir = 
            flag "--working-dir" (required string)
              ~doc:"DIR Working directory where ledgers/configs will be created"
        and precomputed_block_prefix = 
            flag "--precomputed-block-prefix" (optional string)
              ~doc:"STRING Optional prefix for precomputed block (default: gs://mina_network_block_data/<network-name>)"
        in
        fun () -> main network_name fork_config workdir precomputed_block_prefix))