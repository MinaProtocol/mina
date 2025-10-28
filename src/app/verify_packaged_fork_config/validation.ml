(** Core validation logic for packaged fork configuration verification.

    This module contains the high-level validation steps that orchestrate
    the verification process, including ledger generation, export, and comparison.
*)

open Core
open Async

(* Open Types module for convenient access to record fields *)
module Types = Types

(** Resolve all required executable paths from environment or defaults.

    @return Deferred record with all executable paths
*)
let resolve_executables () =
  Log.Global.info "Resolving executable paths" ;
  let%bind mina =
    Shell_operations.resolve_executable_from_env Constants.EnvVars.mina_exe
      "mina" Constants.Executables.mina_fallback
  in
  let%bind mina_genesis =
    Shell_operations.resolve_executable_from_env
      Constants.EnvVars.mina_genesis_exe "mina-create-genesis"
      Constants.Executables.mina_genesis_fallback
  in
  let%bind mina_legacy_genesis =
    Shell_operations.resolve_executable_from_env
      Constants.EnvVars.mina_legacy_genesis_exe "mina-create-legacy-genesis"
      Constants.Executables.mina_legacy_genesis_fallback
  in
  let%bind create_runtime_config =
    Shell_operations.resolve_executable_from_env
      Constants.EnvVars.create_runtime_config "mina-hf-create-runtime-config"
      Constants.Executables.create_runtime_config_fallback
  in
  let%bind gsutil = Shell_operations.find_gsutil () in
  Log.Global.info "All executables resolved successfully" ;
  return
    Types.
      { mina; mina_genesis; mina_legacy_genesis; create_runtime_config; gsutil }

(** Build validation configuration from command-line arguments and environment.

    @param network_name Network name (e.g., mainnet)
    @param fork_config Path to fork config JSON
    @param workdir Working directory
    @param precomputed_block_prefix_arg Optional GCS prefix override
    @return Deferred validation configuration record
*)
let build_validation_config network_name fork_config workdir
    precomputed_block_prefix_arg =
  Log.Global.info "Building validation configuration" ;
  let precomputed_block_prefix =
    match precomputed_block_prefix_arg with
    | Some p ->
        p
    | None ->
        sprintf "gs://mina_network_block_data/%s" network_name
  in
  let%bind executables = resolve_executables () in
  let%bind installed_config =
    Shell_operations.run_command_capture
      (sprintf "echo %s" Constants.Paths.installed_config_glob)
  in
  let packaged_daemon_config =
    Shell_operations.get_env_or_default Constants.EnvVars.packaged_daemon_config
      ( match installed_config with
      | Ok path ->
          String.strip path
      | Error _ ->
          "" )
  in
  (* Verify packaged daemon config exists *)
  let%bind () =
    Log.Global.info "Verifying packaged daemon config exists: %s"
      packaged_daemon_config ;
    match%bind Sys.file_exists packaged_daemon_config with
    | `Yes ->
        Log.Global.info "Packaged daemon config found" ;
        return ()
    | `No | `Unknown ->
        Log.Global.error "Packaged daemon config not found: %s"
          packaged_daemon_config ;
        eprintf
          "Error: set PACKAGED_DAEMON_CONFIG to the path to the JSON file to \
           verify\n\
           %!" ;
        exit 1
  in
  let genesis_ledger_dir =
    Shell_operations.get_env_or_default Constants.EnvVars.genesis_ledger_dir
      Constants.Paths.default_genesis_ledger_dir
  in
  let seconds_per_slot =
    Shell_operations.get_env_or_default Constants.EnvVars.seconds_per_slot
      Constants.Network.default_seconds_per_slot
  in
  let%bind forking_from_config_json =
    match Sys.getenv Constants.EnvVars.forking_from_config_json with
    | Some path ->
        Log.Global.info "Using FORKING_FROM_CONFIG_JSON from environment: %s"
          path ;
        return path
    | None ->
        Log.Global.info
          "FORKING_FROM_CONFIG_JSON not set, searching for mainnet.json" ;
        Shell_operations.resolve_executable_from_env
          Constants.EnvVars.forking_from_config_json
          Constants.Paths.default_forking_from_config
          Constants.Paths.fallback_forking_from_config
  in
  let precomputed_fork_block =
    Sys.getenv Constants.EnvVars.precomputed_fork_block
  in
  let test_ledger_download =
    Option.is_none (Sys.getenv Constants.EnvVars.no_test_ledger_download)
  in
  let mina_log_level =
    Shell_operations.get_env_or_default Constants.EnvVars.mina_log_level
      Constants.Network.default_log_level
  in
  let mina_ledger_s3_bucket =
    Shell_operations.get_env_or_default Constants.EnvVars.mina_ledger_s3_bucket
      Constants.Network.default_s3_bucket
  in
  (* Validate gsutil availability if needed *)
  let%bind () =
    Log.Global.info "Validating precomputed fork block availability" ;
    match precomputed_fork_block with
    | Some path -> (
        Log.Global.info "PRECOMPUTED_FORK_BLOCK set to: %s" path ;
        match%bind Sys.file_exists path with
        | `Yes ->
            Log.Global.info "Precomputed fork block exists" ;
            return ()
        | `No | `Unknown ->
            if String.is_empty executables.gsutil then (
              Log.Global.error
                "gsutil is required when PRECOMPUTED_FORK_BLOCK is nonexistent \
                 path" ;
              eprintf
                "Error: gsutil is required when PRECOMPUTED_FORK_BLOCK is \
                 nonexistent path\n\
                 %!" ;
              exit 1 )
            else return () )
    | None ->
        Log.Global.info "PRECOMPUTED_FORK_BLOCK not set, will fetch with gsutil" ;
        return ()
  in
  return
    Types.
      { network_name
      ; fork_config
      ; workdir
      ; precomputed_block_prefix
      ; packaged_daemon_config
      ; genesis_ledger_dir
      ; seconds_per_slot
      ; forking_from_config_json
      ; executables
      ; precomputed_fork_block
      ; test_ledger_download
      ; mina_log_level
      ; mina_ledger_s3_bucket
      }

(** Obtain the precomputed fork block, either from local path or GCS.

    @param config Validation configuration
    @param fork_block_state_hash State hash of the fork block
    @param fork_block_length Blockchain length of the fork block
    @return Deferred unit
*)
let obtain_precomputed_fork_block (config : Types.validation_config)
    ~fork_block_state_hash ~fork_block_length =
  Log.Global.info "Obtaining precomputed fork block" ;
  let dest_file =
    File_operations.workdir_path config.workdir
      Constants.FileNames.precomputed_fork_block
  in
  match config.precomputed_fork_block with
  | Some path -> (
      Log.Global.info "Checking if precomputed fork block exists at: %s" path ;
      match%bind Sys.file_exists path with
      | `Yes ->
          Log.Global.info "Copying precomputed fork block from: %s" path ;
          File_operations.copy_file ~src:path ~dst:dest_file
      | `No | `Unknown ->
          Log.Global.info
            "Precomputed fork block not found locally, downloading from GCS" ;
          let block_path =
            sprintf "%s-%s-%s.json" config.precomputed_block_prefix
              fork_block_length fork_block_state_hash
          in
          Shell_operations.run_command
            (sprintf "%s cp %s %s" config.executables.gsutil
               (Filename.quote block_path)
               (Filename.quote dest_file) )
          |> Deferred.ignore_m )
  | None ->
      Log.Global.info "Downloading precomputed fork block from GCS" ;
      let block_path =
        sprintf "%s-%s-%s.json" config.precomputed_block_prefix
          fork_block_length fork_block_state_hash
      in
      Shell_operations.run_command
        (sprintf "%s cp %s %s" config.executables.gsutil
           (Filename.quote block_path)
           (Filename.quote dest_file) )
      |> Deferred.ignore_m

(** Generate libp2p keypair if it doesn't already exist.

    @param config Validation configuration
    @return Deferred unit
*)
let ensure_libp2p_keypair (config : Types.validation_config) =
  let p2p_key_path =
    File_operations.workdir_path config.workdir
      (Filename.concat Constants.Subdirs.keys Constants.FileNames.p2p_key)
  in
  Log.Global.info "Checking for libp2p keypair at: %s" p2p_key_path ;
  match%bind Sys.file_exists p2p_key_path with
  | `Yes ->
      Log.Global.info "libp2p keypair already exists" ;
      return ()
  | `No | `Unknown ->
      Log.Global.info "Generating new libp2p keypair" ;
      Shell_operations.run_command
        ~env:[ (Constants.EnvVars.mina_libp2p_pass, "") ]
        (sprintf "%s libp2p generate-keypair --privkey-path %s"
           config.executables.mina
           (Filename.quote p2p_key_path) )
      |> Deferred.ignore_m

(** Generate legacy format ledgers and hash file.

    @param config Validation configuration
    @return Deferred unit
*)
let generate_legacy_ledgers (config : Types.validation_config) =
  Log.Global.info "Generating legacy ledgers" ;
  let config_file =
    File_operations.workdir_path config.workdir Constants.FileNames.config
  in
  let legacy_ledgers_dir =
    File_operations.workdir_path config.workdir Constants.Subdirs.legacy_ledgers
  in
  let hashes_file =
    File_operations.workdir_path config.workdir
      Constants.FileNames.legacy_hashes
  in
  Shell_operations.run_command
    (sprintf "%s --config-file %s --genesis-dir %s --hash-output-file %s"
       config.executables.mina_legacy_genesis
       (Filename.quote config_file)
       (Filename.quote legacy_ledgers_dir)
       (Filename.quote hashes_file) )
  |> Deferred.ignore_m

(** Generate new format ledgers and hash file.

    @param config Validation configuration
    @return Deferred unit
*)
let generate_new_ledgers (config : Types.validation_config) =
  Log.Global.info "Generating new ledgers with patched config" ;
  let config_file =
    File_operations.workdir_path config.workdir Constants.FileNames.config
  in
  let ledgers_dir =
    File_operations.workdir_path config.workdir Constants.Subdirs.ledgers
  in
  let hashes_file =
    File_operations.workdir_path config.workdir Constants.FileNames.hashes
  in
  Shell_operations.run_command
    (sprintf "%s --config-file %s --genesis-dir %s --hash-output-file %s"
       config.executables.mina_genesis
       (Filename.quote config_file)
       (Filename.quote ledgers_dir)
       (Filename.quote hashes_file) )
  |> Deferred.ignore_m
