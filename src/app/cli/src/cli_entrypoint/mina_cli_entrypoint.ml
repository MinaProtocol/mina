open Core
open Async
open Cli_lib
open Signature_lib
open Init
module YJ = Yojson.Safe

type mina_initialization =
  { mina : Mina_lib.t
  ; client_trustlist : Unix.Cidr.t list option
  ; rest_server_port : int
  ; limited_graphql_port : int option
  ; itn_graphql_port : int option
  }

let make_ledger_backing ~constraint_constants ~runtime_config ~hardfork_handling
    =
  let current_genesis_global_slot =
    let%map.Option { global_slot_since_genesis = current_genesis_global_slot
                   ; _
                   } =
      constraint_constants.Genesis_constants.Constraint_constants.fork
    in
    current_genesis_global_slot
  in
  let hardfork_slot =
    let%map.Option hardfork_slot_since_last_hf =
      Runtime_config.scheduled_hard_fork_genesis_slot runtime_config
    in
    Mina_numbers.Global_slot_since_hard_fork.to_global_slot_since_genesis
      ~current_genesis_global_slot hardfork_slot_since_last_hf
  in

  match (hardfork_handling, hardfork_slot) with
  | Cli_lib.Arg_type.Hardfork_handling.Migrate_exit, Some hardfork_slot ->
      Mina_ledger.Root.Config.Converting_db hardfork_slot
  | Migrate_exit, _ ->
      failwith
        "No hardfork slot provided for Migrate_exit mode, \
         `daemon.{slot_chain_end,hard_fork_genesis_slot_delta}` need to be \
         configured for using this HF mode."
  | Keep_running, _ ->
      Stable_db

let load_config_files ~logger ~genesis_constants ~constraint_constants ~conf_dir
    ~genesis_dir ~cli_proof_level ~proof_level ~hardfork_handling config_files =
  let%bind config_jsons =
    let config_files_paths =
      List.map config_files ~f:(fun (config_file, _) -> `String config_file)
    in
    [%log info] "Reading configuration files $config_files"
      ~metadata:[ ("config_files", `List config_files_paths) ] ;
    Deferred.List.filter_map config_files
      ~f:(fun (config_file, handle_missing) ->
        match%bind Genesis_ledger_helper.load_config_json config_file with
        | Ok config_json ->
            let%map config_json =
              Genesis_ledger_helper.upgrade_old_config ~logger config_file
                config_json
            in
            Some (config_file, config_json)
        | Error err -> (
            match handle_missing with
            | `Must_exist ->
                Mina_stdlib.Mina_user_error.raisef
                  ~where:"reading configuration file"
                  "The configuration file %s could not be read:\n%s" config_file
                  (Error.to_string_hum err)
            | `May_be_missing ->
                [%log warn] "Could not read configuration from $config_file"
                  ~metadata:
                    [ ("config_file", `String config_file)
                    ; ("error", Error_json.error_to_yojson err)
                    ] ;
                return None ) )
  in
  let config =
    List.fold ~init:Runtime_config.default config_jsons
      ~f:(fun config (config_file, config_json) ->
        match Runtime_config.of_yojson config_json with
        | Ok loaded_config ->
            Runtime_config.combine config loaded_config
        | Error err ->
            [%log fatal]
              "Could not parse configuration from $config_file: $error"
              ~metadata:
                [ ("config_file", `String config_file)
                ; ("config_json", config_json)
                ; ("error", `String err)
                ] ;
            failwithf "Could not parse configuration file: %s" err () )
  in
  let chain_state_locations, chain_id_opt =
    Init.Chain_state_locations.of_config ~logger
      ~signature_kind:Mina_signature_kind.t_DEPRECATED ~proof_level
      ~genesis_constants ~constraint_constants ~conf_dir config
  in
  let genesis_dir =
    Option.value ~default:chain_state_locations.genesis genesis_dir
  in
  let%map precomputed_values =
    match%map
      Genesis_ledger_helper.init_from_config_file ~cli_proof_level ~genesis_dir
        ~logger ~genesis_constants ~constraint_constants ~proof_level config
    with
    | Ok precomputed_values ->
        precomputed_values
    | Error err ->
        let ( json_config
            , `Accounts_omitted
                ( `Genesis genesis_accounts_omitted
                , `Staking staking_accounts_omitted
                , `Next next_accounts_omitted ) ) =
          Runtime_config.to_yojson_without_accounts config
        in
        let append_accounts_omitted s =
          Option.value_map
            ~f:(fun i -> List.cons (s ^ "_accounts_omitted", `Int i))
            ~default:Fn.id
        in
        let metadata =
          append_accounts_omitted "genesis" genesis_accounts_omitted
          @@ append_accounts_omitted "staking" staking_accounts_omitted
          @@ append_accounts_omitted "next" next_accounts_omitted []
          @ [ ("config", json_config)
            ; ( "name"
              , `String
                  (Option.value ~default:"not provided"
                     (let%bind.Option ledger = config.ledger in
                      Option.first_some ledger.name ledger.hash ) ) )
            ; ("error", Error_json.error_to_yojson err)
            ]
        in
        [%log info]
          "Initializing with runtime configuration. Ledger source: $name"
          ~metadata ;
        Error.raise err
  in
  let chain_id = Chain_id.of_precomputed_values precomputed_values in
  let _ =
    match chain_id_opt with
    | None ->
        ()
    | Some cid ->
        let open Chain_id in
        let chain_id = Lazy.force chain_id in
        if not (Chain_id.equal cid chain_id) then
          failwithf "Chain_id mismatch %s /= %s" (to_string cid)
            (to_string chain_id) ()
  in
  let ledger_backing =
    make_ledger_backing
      ~constraint_constants:precomputed_values.constraint_constants
      ~runtime_config:config ~hardfork_handling
  in
  ( precomputed_values
  , config_jsons
  , config
  , chain_state_locations
  , ledger_backing
  , chain_id )

(** The configuration files to read, in increasing order of precedence, each
    marked with whether it is an error for it to be missing. *)
let daemon_config_files ~conf_dir config_files =
  let config_file_installed =
    (* Search for config files installed as part of a deb/brew package.
       These files are commit-dependent, to ensure that we don't clobber
       configuration for dev builds or use incompatible configs.
    *)
    let config_file_installed =
      let json = "config_" ^ Mina_version.commit_id_short ^ ".json" in
      List.fold_until ~init:None
        (Cache_dir.possible_paths json)
        ~f:(fun _acc f ->
          match Core.Sys.file_exists f with
          | `Yes ->
              Stop (Some f)
          | _ ->
              Continue None )
        ~finish:Fn.id
    in
    match config_file_installed with
    | Some config_file ->
        Some (config_file, `Must_exist)
    | None ->
        None
  in
  let config_file_configdir = (conf_dir ^/ "daemon.json", `May_be_missing) in
  let config_file_envvar =
    match Sys.getenv "MINA_CONFIG_FILE" with
    | Some config_file ->
        Some (config_file, `Must_exist)
    | None ->
        None
  in
  Option.to_list config_file_installed
  @ (config_file_configdir :: Option.to_list config_file_envvar)
  @ List.map config_files ~f:(fun config_file -> (config_file, `Must_exist))

let setup_daemon logger ~itn_features ~default_snark_worker_fee =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  let%map { Daemon_flags.conf_dir
          ; block_production_key
          ; block_production_pubkey
          ; block_production_password
          ; itn_keys
          ; itn_max_logs
          ; demo_mode
          ; coinbase_receiver_flag
          ; genesis_dir
          ; run_snark_worker_flag
          ; run_snark_coordinator_flag
          ; snark_worker_parallelism_flag
          ; work_selection_method_flag
          ; libp2p_port
          ; client_port
          ; rest_server_port
          ; limited_graphql_port
          ; itn_graphql_port
          ; open_limited_graphql_port
          ; archive_process_location
          ; metrics_server_port
          ; gc_stat_interval
          ; libp2p_metrics_port
          ; external_ip_opt
          ; bind_ip_opt
          ; working_dir
          ; is_background
          ; is_archive_rocksdb
          ; log_json
          ; log_level
          ; file_log_level
          ; file_log_rotations
          ; snark_work_fee
          ; work_reassignment_wait
          ; enable_tracing
          ; enable_internal_tracing
          ; insecure_rest_server
          ; log_received_snark_pool_diff
          ; log_transaction_pool_diff
          ; log_block_creation
          ; libp2p_keypair
          ; is_seed
          ; enable_flooding
          ; peer_exchange
          ; peer_protection_ratio
          ; min_connections
          ; max_connections
          ; validation_queue_size
          ; direct_peers_raw
          ; isolate
          ; libp2p_peers_raw
          ; libp2p_peer_list_file
          ; seed_peer_list_url
          ; proposed_protocol_version
          ; config_files
          ; disable_node_status
          ; cli_proof_level
          ; precomputed_blocks_path
          ; precomputed_blocks_dir
          ; log_precomputed_blocks
          ; start_filtered_logs
          ; block_reward_threshold
          ; stop_time
          ; stop_time_interval
          ; upload_blocks_to_gcloud
          ; all_peers_seen_metric
          ; node_status_url
          ; node_error_url
          ; simplified_node_stats
          ; contact_info
          ; uptime_url_string
          ; uptime_submitter_key
          ; uptime_submitter_pubkey
          ; uptime_send_node_commit
          ; hardfork_handling
          } =
    Daemon_flags.param ~itn_features ~default_snark_worker_fee
  in
  let to_pubsub_topic_mode_option =
    let open Gossip_net.Libp2p in
    function
    | `String "ro" ->
        Some RO
    | `String "rw" ->
        Some RW
    | `String "none" ->
        Some N
    | `Null ->
        None
    | _ ->
        raise (Error.to_exn (Error.of_string "Invalid pubsub topic mode"))
  in
  fun () ->
    let conf_dir = Mina_lib.Conf_dir.compute_conf_dir_exn conf_dir in
    O1trace.thread "mina" (fun () ->
        let open Deferred.Let_syntax in
        let%bind () = Mina_stdlib_unix.File_system.create_dir conf_dir in
        let () =
          if is_background then (
            Core.printf "Starting background mina daemon. (Log Dir: %s)\n%!"
              conf_dir ;
            Daemon.daemonize ~allow_threads_to_have_been_created:true
              ~redirect_stdout:`Dev_null ?cd:working_dir
              ~redirect_stderr:`Dev_null () )
          else Option.iter working_dir ~f:Caml.Sys.chdir
        in
        (* NOTE: invocation of memtrace must happen after daemonization *)
        Memtrace.trace_if_requested ~context:"mina" () ;
        Stdout_log.setup log_json log_level ;
        (* 512MB logrotate max size = 1GB max filesystem usage *)
        let logrotate_max_size = 1024 * 1024 * 10 in
        Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
          ~id:Logger.Logger_id.mina
          ~processor:(Logger.Processor.raw ~log_level:file_log_level ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina.log" ~max_size:logrotate_max_size
               ~num_rotate:file_log_rotations )
          () ;
        let best_tip_diff_log_size = 1024 * 1024 * 5 in
        Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
          ~id:Logger.Logger_id.best_tip_diff
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina-best-tip.log"
               ~max_size:best_tip_diff_log_size ~num_rotate:1 )
          () ;
        let rejected_blocks_log_size = 1024 * 1024 * 5 in
        Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
          ~id:Logger.Logger_id.rejected_blocks
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina-rejected-blocks.log"
               ~max_size:rejected_blocks_log_size ~num_rotate:50 )
          () ;
        Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
          ~id:Logger.Logger_id.oversized_logs
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina-oversized-logs.log"
               ~max_size:logrotate_max_size ~num_rotate:20 )
          () ;
        (* Consumer for `[%log internal]` logging used for internal tracing *)
        Itn_logger.set_message_postprocessor
          Internal_tracing.For_itn_logger.post_process_message ;
        Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
          ~id:Logger.Logger_id.mina
          ~processor:Internal_tracing.For_logger.processor
          ~transport:
            (Internal_tracing.For_logger.json_lines_rotate_transport
               ~directory:(conf_dir ^ "/internal-tracing")
               () )
          () ;
        let version_metadata = [ ("commit", `String Mina_version.commit_id) ] in
        [%log info] "Mina daemon is booting up; built with commit $commit"
          ~metadata:version_metadata ;
        let%bind () =
          Mina_lib.Conf_dir.check_and_set_lockfile ~logger conf_dir
        in
        [%log info] "Booting may take several seconds, please wait" ;
        let wallets_disk_location = conf_dir ^/ "wallets" in
        let%bind wallets =
          (* Load wallets early, to give user errors before expensive
             initialization starts.
          *)
          Secrets.Wallets.load ~logger ~disk_location:wallets_disk_location
        in
        let%bind libp2p_keypair =
          let libp2p_keypair_old_format =
            Option.bind libp2p_keypair ~f:(fun libp2p_keypair ->
                match Mina_net2.Keypair.of_string libp2p_keypair with
                | Ok kp ->
                    Some kp
                | Error _ ->
                    if String.contains libp2p_keypair ',' then
                      [%log warn]
                        "I think -libp2p-keypair is in the old format, but I \
                         failed to parse it! Using it as a path..." ;
                    None )
          in
          match libp2p_keypair_old_format with
          | Some kp ->
              return (Some kp)
          | None -> (
              match libp2p_keypair with
              | None ->
                  return None
              | Some s ->
                  Secrets.Libp2p_keypair.Terminal_stdin.read_exn
                    ~should_prompt_user:false ~which:"libp2p keypair" s
                  |> Deferred.map ~f:Option.some )
        in
        let%bind () =
          let version_filename = conf_dir ^/ "mina.version" in
          let make_version () =
            let%map () =
              (*Delete any trace files if version changes. TODO: Implement rotate logic similar to log files*)
              Mina_stdlib_unix.File_system.remove_dir (conf_dir ^/ "trace")
            in
            Yojson.Safe.to_file version_filename (`Assoc version_metadata)
          in
          match
            Or_error.try_with_join (fun () ->
                match Yojson.Safe.from_file version_filename with
                | `Assoc list -> (
                    match String.Map.(find (of_alist_exn list) "commit") with
                    | Some (`String commit) ->
                        Ok commit
                    | _ ->
                        Or_error.errorf "commit not found in version file %s"
                          version_filename )
                | _ ->
                    Or_error.errorf "Unexpected value in %s" version_filename )
          with
          | Ok c ->
              if String.equal c Mina_version.commit_id then return ()
              else (
                [%log warn]
                  "Different version of Mina detected in config directory \
                   $config_directory, removing existing configuration"
                  ~metadata:[ ("config_directory", `String conf_dir) ] ;
                make_version () )
          | Error e ->
              [%log debug]
                "Error reading $file: $error. Cleaning up the config directory \
                 $config_directory"
                ~metadata:
                  [ ("error", `String (Error.to_string_mach e))
                  ; ("config_directory", `String conf_dir)
                  ; ("file", `String version_filename)
                  ] ;
              make_version ()
        in
        Parallel.init_master () ;
        let monitor = Async.Monitor.create ~name:"coda" () in
        let time_controller = Block_time.Controller.basic ~logger in
        let pids = Child_processes.Termination.create_pid_table () in
        let mina_initialization_deferred () =
          let config_files = daemon_config_files ~conf_dir config_files in

          let (module G) = Genesis_constants.profiled () in
          let genesis_constants = G.genesis_constants in
          let constraint_constants = G.constraint_constants in
          [%log info] "Daemon running with node profile $profile"
            ~metadata:
              [ ("profile", `String Node_config.profile)
              ; ( "constraint_constants"
                , Genesis_constants.Constraint_constants.to_yojson
                    constraint_constants )
              ] ;
          let compile_config =
            Mina_compile_config.of_node_config (module Node_config)
          in
          let%bind ( precomputed_values
                   , config_jsons
                   , config
                   , chain_state_locations
                   , ledger_backing
                   , chain_id ) =
            load_config_files ~logger ~conf_dir ~genesis_dir
              ~proof_level:G.proof_level config_files ~genesis_constants
              ~constraint_constants ~cli_proof_level ~hardfork_handling
          in
          constraint_constants.block_window_duration_ms |> Float.of_int
          |> Time.Span.of_ms |> Mina_metrics.initialize_all ;

          let rev_daemon_configs =
            List.rev_filter_map config_jsons
              ~f:(fun (config_file, config_json) ->
                Option.map
                  YJ.Util.(
                    to_option Fn.id (YJ.Util.member "daemon" config_json))
                  ~f:(fun daemon_config -> (config_file, daemon_config)) )
          in
          let maybe_from_config (type a) (f : YJ.t -> a option)
              (keyname : string) (actual_value : a option) : a option =
            let open Option.Let_syntax in
            let open YJ.Util in
            match actual_value with
            | Some v ->
                Some v
            | None ->
                (* Load value from the latest config file that both
                   * has the key we are looking for, and
                   * has the key in a format that [f] can parse.
                *)
                let%map config_file, data =
                  List.find_map rev_daemon_configs
                    ~f:(fun (config_file, daemon_config) ->
                      let%bind json_val =
                        to_option Fn.id (member keyname daemon_config)
                      in
                      let%map data = f json_val in
                      (config_file, data) )
                in
                [%log debug] "Key $key being used from config file $config_file"
                  ~metadata:
                    [ ("key", `String keyname)
                    ; ("config_file", `String config_file)
                    ] ;
                data
          in
          let or_from_config map keyname actual_value ~default =
            match maybe_from_config map keyname actual_value with
            | Some x ->
                x
            | None ->
                [%log trace]
                  "Key '$key' not found in the config file, using default"
                  ~metadata:[ ("key", `String keyname) ] ;
                default
          in
          let get_port { Flag.Types.value; default; name } =
            or_from_config YJ.Util.to_int_option name ~default value
          in
          let libp2p_port = get_port libp2p_port in
          let rest_server_port = get_port rest_server_port in
          let limited_graphql_port =
            let ({ value; name } : int option Flag.Types.with_name) =
              limited_graphql_port
            in
            maybe_from_config YJ.Util.to_int_option name value
          in
          let client_port = get_port client_port in
          let snark_work_fee_flag =
            let json_to_currency_fee_option json =
              YJ.Util.to_int_option json
              |> Option.map ~f:Currency.Fee.of_nanomina_int_exn
            in
            or_from_config json_to_currency_fee_option "snark-worker-fee"
              ~default:compile_config.default_snark_worker_fee snark_work_fee
          in
          let node_status_url =
            maybe_from_config YJ.Util.to_string_option "node-status-url"
              node_status_url
          in
          (* FIXME #4095: pass this through to Gossip_net.Libp2p *)
          let _max_concurrent_connections =
            (*if
                 or_from_config YJ.Util.to_bool_option "max-concurrent-connections"
                   ~default:true limit_connections
               then Some 40
               else *)
            None
          in
          let work_selection_method =
            or_from_config
              (Fn.compose Option.return
                 (Fn.compose work_selection_method_val YJ.Util.to_string) )
              "work-selection"
              ~default:Cli_lib.Arg_type.Work_selection_method.Random
              work_selection_method_flag
          in
          let work_reassignment_wait =
            or_from_config YJ.Util.to_int_option "work-reassignment-wait"
              ~default:Cli_lib.Default.work_reassignment_wait
              work_reassignment_wait
          in
          let log_received_snark_pool_diff =
            or_from_config YJ.Util.to_bool_option "log-snark-work-gossip"
              ~default:false log_received_snark_pool_diff
          in
          let log_transaction_pool_diff =
            or_from_config YJ.Util.to_bool_option "log-txn-pool-gossip"
              ~default:false log_transaction_pool_diff
          in
          let log_block_creation =
            or_from_config YJ.Util.to_bool_option "log-block-creation"
              ~default:true log_block_creation
          in
          let log_gossip_heard =
            { Mina_networking.Config.snark_pool_diff =
                log_received_snark_pool_diff
            ; transaction_pool_diff = log_transaction_pool_diff
            ; new_state = true
            }
          in
          let json_to_publickey_compressed_option which json =
            YJ.Util.to_string_option json
            |> Option.bind ~f:(fun pk_str ->
                   match Public_key.Compressed.of_base58_check pk_str with
                   | Ok key -> (
                       match Public_key.decompress key with
                       | None ->
                           Mina_stdlib.Mina_user_error.raisef
                             ~where:"decompressing a public key"
                             "The %s public key %s could not be decompressed."
                             which pk_str
                       | Some _ ->
                           Some key )
                   | Error _e ->
                       Mina_stdlib.Mina_user_error.raisef
                         ~where:"decoding a public key"
                         "The %s public key %s could not be decoded." which
                         pk_str )
          in
          let run_snark_worker_flag =
            maybe_from_config
              (json_to_publickey_compressed_option "snark worker")
              "run-snark-worker" run_snark_worker_flag
          in
          let run_snark_coordinator_flag =
            maybe_from_config
              (json_to_publickey_compressed_option "snark coordinator")
              "run-snark-coordinator" run_snark_coordinator_flag
          in
          let snark_worker_parallelism_flag =
            maybe_from_config YJ.Util.to_int_option "snark-worker-parallelism"
              snark_worker_parallelism_flag
          in
          let coinbase_receiver_flag =
            maybe_from_config
              (json_to_publickey_compressed_option "coinbase receiver")
              "coinbase-receiver" coinbase_receiver_flag
          in
          let%bind external_ip =
            match external_ip_opt with
            | None ->
                Find_ip.find ~logger
            | Some ip ->
                return @@ Unix.Inet_addr.of_string ip
          in
          let bind_ip =
            Option.value bind_ip_opt ~default:"0.0.0.0"
            |> Unix.Inet_addr.of_string
          in
          let addrs_and_ports : Node_addrs_and_ports.t =
            { external_ip; bind_ip; peer = None; client_port; libp2p_port }
          in
          let block_production_key =
            maybe_from_config YJ.Util.to_string_option "block-producer-key"
              block_production_key
          in
          let block_production_pubkey =
            maybe_from_config
              (json_to_publickey_compressed_option "block producer")
              "block-producer-pubkey" block_production_pubkey
          in
          let block_production_password =
            maybe_from_config YJ.Util.to_string_option "block-producer-password"
              block_production_password
          in
          Option.iter
            ~f:(fun password ->
              match Sys.getenv Secrets.Keypair.env with
              | Some env_pass when not (String.equal env_pass password) ->
                  [%log warn]
                    "$envkey environment variable doesn't match value provided \
                     on command-line or daemon.json. Using value from $envkey"
                    ~metadata:[ ("envkey", `String Secrets.Keypair.env) ]
              | _ ->
                  Unix.putenv ~key:Secrets.Keypair.env ~data:password )
            block_production_password ;
          let%bind block_production_keypair =
            match
              ( block_production_key
              , block_production_pubkey
              , Sys.getenv "MINA_BP_PRIVKEY" )
            with
            | Some _, Some _, _ ->
                Mina_stdlib.Mina_user_error.raise
                  "You cannot provide both `block-producer-key` and \
                   `block_production_pubkey`"
            | None, Some _, Some _ ->
                Mina_stdlib.Mina_user_error.raise
                  "You cannot provide both `MINA_BP_PRIVKEY` and \
                   `block_production_pubkey`"
            | None, None, None ->
                Deferred.return None
            | None, None, Some base58_privkey ->
                let kp =
                  Private_key.of_base58_check_exn base58_privkey
                  |> Keypair.of_private_key_exn
                in
                Deferred.return (Some kp)
            (* CLI argument takes precedence over env variable *)
            | Some sk_file, None, (Some _ | None) ->
                [%log warn]
                  "`block-producer-key` is deprecated. Please set \
                   `MINA_BP_PRIVKEY` environment variable instead." ;
                let%map kp =
                  Secrets.Keypair.Terminal_stdin.read_exn
                    ~should_prompt_user:false ~which:"block producer keypair"
                    sk_file
                in
                Some kp
            | None, Some tracked_pubkey, None ->
                let%map kp =
                  Secrets.Wallets.get_tracked_keypair ~logger
                    ~which:"block producer keypair"
                    ~read_from_env_exn:
                      (Secrets.Keypair.Terminal_stdin.read_exn
                         ~should_prompt_user:false ~should_reask:false )
                    ~conf_dir tracked_pubkey
                in
                Some kp
          in
          let%bind client_trustlist =
            Reader.load_sexp
              (conf_dir ^/ "client_trustlist")
              [%of_sexp: Unix.Cidr.t list]
            >>| Or_error.ok
          in
          let client_trustlist =
            let mina_client_trustlist = "MINA_CLIENT_TRUSTLIST" in
            let cidrs_of_env_str env_str env_var =
              let cidrs =
                String.split ~on:',' env_str
                |> List.filter_map ~f:(fun str ->
                       try Some (Unix.Cidr.of_string str)
                       with _ ->
                         [%log warn] "Could not parse address $address in %s"
                           env_var
                           ~metadata:[ ("address", `String str) ] ;
                         None )
              in
              Some
                (List.append cidrs (Option.value ~default:[] client_trustlist))
            in
            match Unix.getenv mina_client_trustlist with
            | Some env_str ->
                cidrs_of_env_str env_str mina_client_trustlist
            | None ->
                client_trustlist
          in
          let get_monitor_infos monitor =
            let rec get_monitors accum monitor =
              match Async_kernel.Monitor.parent monitor with
              | None ->
                  List.rev accum
              | Some parent ->
                  get_monitors (parent :: accum) parent
            in
            let monitors = get_monitors [ monitor ] monitor in
            List.map monitors ~f:(fun monitor ->
                match Async_kernel.Monitor.sexp_of_t monitor with
                | Sexp.List sexps ->
                    `List (List.map ~f:Error_json.sexp_record_to_yojson sexps)
                | Sexp.Atom _ ->
                    failwith "Expected a sexp list" )
          in
          let o1trace context =
            Execution_context.find_local context O1trace.local_storage_id
            |> Option.value ~default:[]
            |> List.map ~f:(fun x -> `String x)
          in
          Stream.iter
            (Async_kernel.Async_kernel_scheduler.long_cycles_with_context
               ~at_least:(sec 0.5 |> Time_ns.Span.of_span_float_round_nearest) )
            ~f:(fun (span, context) ->
              let secs = Time_ns.Span.to_sec span in
              let monitor_infos = get_monitor_infos context.monitor in
              let o1trace = o1trace context in
              [%log internal] "Long_async_cycle"
                ~metadata:
                  [ ("duration", `Float secs); ("trace", `List o1trace) ] ;
              [%log debug]
                ~metadata:
                  [ ("long_async_cycle", `Float secs)
                  ; ("monitors", `List monitor_infos)
                  ; ("o1trace", `List o1trace)
                  ]
                "Long async cycle, $long_async_cycle seconds, $monitors, \
                 $o1trace" ;
              Mina_metrics.(
                Runtime.Long_async_histogram.observe Runtime.long_async_cycle
                  secs) ) ;
          Stream.iter Async_kernel.Async_kernel_scheduler.long_jobs_with_context
            ~f:(fun (context, span) ->
              let secs = Time_ns.Span.to_sec span in
              let monitor_infos = get_monitor_infos context.monitor in
              let o1trace = o1trace context in
              [%log internal] "Long_async_job"
                ~metadata:
                  [ ("duration", `Float secs); ("trace", `List o1trace) ] ;
              [%log debug]
                ~metadata:
                  [ ("long_async_job", `Float secs)
                  ; ("monitors", `List monitor_infos)
                  ; ("o1trace", `List o1trace)
                  ; ( "most_recent_2_backtrace"
                    , `String
                        (String.concat ~sep:"␤"
                           (List.map ~f:Backtrace.to_string
                              (List.take
                                 (Execution_context.backtrace_history context)
                                 2 ) ) ) )
                  ]
                "Long async job, $long_async_job seconds, $monitors, $o1trace" ;
              Mina_metrics.(
                Runtime.Long_job_histogram.observe Runtime.long_async_job secs) ) ;
          let trace_database_initialization typ location =
            (* can't use %log ppx here, because we're using the passed-in location *)
            Logger.trace logger ~module_:__MODULE__ "Creating %s at %s"
              ~location typ
          in
          let trust_dir = chain_state_locations.trust in
          let%bind () = Async.Unix.mkdir ~p:() trust_dir in
          let%bind trust_system = Trust_system.create trust_dir in
          trace_database_initialization "trust_system" __LOC__ trust_dir ;
          let genesis_ledger_hash =
            Precomputed_values.genesis_ledger precomputed_values
            |> Lazy.force |> Mina_ledger.Ledger.merkle_root
          in
          let block_production_keypairs =
            block_production_keypair
            |> Option.map ~f:(fun kp ->
                   (kp, Public_key.compress kp.Keypair.public_key) )
            |> Option.to_list |> Keypair.And_compressed_pk.Set.of_list
          in
          let epoch_ledger_location =
            chain_state_locations.epoch_ledger ^/ "epoch_ledger"
          in
          let module Context = struct
            let logger = logger

            let constraint_constants = precomputed_values.constraint_constants

            let consensus_constants = precomputed_values.consensus_constants
          end in
          let consensus_local_state =
            Consensus.Data.Local_state.create
              ~context:(module Context)
              ~genesis_ledger:precomputed_values.genesis_ledger
              ~genesis_epoch_data:precomputed_values.genesis_epoch_data
              ~epoch_ledger_location
              ( Option.map block_production_keypair ~f:(fun keypair ->
                    let open Keypair in
                    Public_key.compress keypair.public_key )
              |> Option.to_list |> Public_key.Compressed.Set.of_list )
              ~genesis_state_hash:
                precomputed_values.protocol_state_with_hashes.hash.state_hash
              ~epoch_ledger_backing_type:ledger_backing
          in
          trace_database_initialization "epoch ledger" __LOC__
            epoch_ledger_location ;
          let%bind peer_list_file_contents_or_empty =
            match libp2p_peer_list_file with
            | None ->
                return []
            | Some file -> (
                match%bind
                  Monitor.try_with_or_error ~here:[%here] (fun () ->
                      Reader.file_contents file )
                with
                | Ok contents ->
                    return (Mina_net2.Multiaddr.of_file_contents contents)
                | Error _ ->
                    Mina_stdlib.Mina_user_error.raisef
                      ~where:"reading libp2p peer address file"
                      "The file %s could not be read.\n\n\
                       It must be a newline-separated list of libp2p \
                       multiaddrs (ex: /ip4/IPADDR/tcp/PORT/p2p/PEERID)"
                      file )
          in
          List.iter libp2p_peers_raw ~f:(fun raw_peer ->
              if not Mina_net2.Multiaddr.(valid_as_peer @@ of_string raw_peer)
              then
                Mina_stdlib.Mina_user_error.raisef
                  ~where:"decoding peer as a multiaddress"
                  "The given peer \"%s\" is not a valid multiaddress (ex: \
                   /ip4/IPADDR/tcp/PORT/p2p/PEERID)"
                  raw_peer ) ;
          let initial_peers =
            List.concat
              [ List.map ~f:Mina_net2.Multiaddr.of_string libp2p_peers_raw
              ; peer_list_file_contents_or_empty
              ; List.map ~f:Mina_net2.Multiaddr.of_string
                @@ or_from_config
                     (Fn.compose Option.some
                        (YJ.Util.convert_each YJ.Util.to_string) )
                     "peers" None ~default:[]
              ]
          in
          let direct_peers =
            List.map ~f:Mina_net2.Multiaddr.of_string direct_peers_raw
          in
          let min_connections =
            or_from_config YJ.Util.to_int_option "min-connections"
              ~default:Cli_lib.Default.min_connections min_connections
          in
          let max_connections =
            or_from_config YJ.Util.to_int_option "max-connections"
              ~default:Cli_lib.Default.max_connections max_connections
          in
          let pubsub_v1 = Gossip_net.Libp2p.N in
          (* TODO uncomment after introducing Bitswap-based block retrieval *)
          (* let pubsub_v1 =
               or_from_config to_pubsub_topic_mode_option "pubsub-v1"
                 ~default:Cli_lib.Default.pubsub_v1 pubsub_v1
             in *)
          let pubsub_v0 =
            or_from_config to_pubsub_topic_mode_option "pubsub-v0"
              ~default:Cli_lib.Default.pubsub_v0 None
          in
          let validation_queue_size =
            or_from_config YJ.Util.to_int_option "validation-queue-size"
              ~default:Cli_lib.Default.validation_queue_size
              validation_queue_size
          in
          let stop_time =
            or_from_config YJ.Util.to_int_option "stop-time"
              ~default:Cli_lib.Default.stop_time stop_time
          in
          let stop_time_interval =
            or_from_config YJ.Util.to_int_option "stop-time-interval"
              ~default:Cli_lib.Default.stop_time_interval stop_time_interval
          in
          if enable_tracing then Mina_tracing.start conf_dir |> don't_wait_for ;
          let%bind () =
            if enable_internal_tracing then
              Internal_tracing.toggle ~commit_id:Mina_version.commit_id ~logger
                `Enabled
            else Deferred.unit
          in
          let seed_peer_list_url =
            Option.value_map seed_peer_list_url ~f:Option.some
              ~default:
                (Option.bind config.daemon
                   ~f:(fun { Runtime_config.Daemon.peer_list_url; _ } ->
                     peer_list_url ) )
          in
          Option.iter seed_peer_list_url ~f:(fun url ->
              match Uri.scheme (Uri.of_string url) with
              | Some "https" ->
                  ()
              | Some "http" ->
                  [%log warn]
                    "The --peer-list-url $url uses HTTP instead of HTTPS. This \
                     is insecure and not recommended."
                    ~metadata:[ ("url", `String url) ]
              | _ ->
                  Mina_stdlib.Mina_user_error.raisef
                    ~where:"validating peer-list-url scheme"
                    "The --peer-list-url must be a valid URL starting with \
                     http:// or https://, but got: %s"
                    url ) ;
          if is_seed then [%log info] "Starting node as a seed node"
          else if demo_mode then [%log info] "Starting node in demo mode"
          else if
            List.is_empty initial_peers && Option.is_none seed_peer_list_url
          then
            Mina_stdlib.Mina_user_error.raise
              {|No peers were given.

Pass one of -peer, -peer-list-file, -seed, -peer-list-url.|} ;
          let chain_id = Lazy.force chain_id |> Chain_id.to_string in
          [%log info] "Daemon will use chain id %s" chain_id ;
          [%log info] "Daemon running protocol version %s"
            Protocol_version.(to_string current) ;
          let gossip_net_params =
            Gossip_net.Libp2p.Config.
              { timeout = Time.Span.of_sec 3.
              ; logger
              ; mina_net_location = chain_state_locations.mina_net
              ; chain_id
              ; unsafe_no_trust_ip = false
              ; seed_peer_list_url =
                  Option.map seed_peer_list_url ~f:Uri.of_string
              ; initial_peers
              ; addrs_and_ports
              ; metrics_port = libp2p_metrics_port
              ; trust_system
              ; flooding = Option.value ~default:false enable_flooding
              ; direct_peers
              ; peer_protection_ratio
              ; peer_exchange = Option.value ~default:false peer_exchange
              ; min_connections
              ; max_connections
              ; validation_queue_size
              ; isolate = Option.value ~default:false isolate
              ; keypair = libp2p_keypair
              ; all_peers_seen_metric
              ; known_private_ip_nets =
                  Option.value ~default:[] client_trustlist
              ; time_controller
              ; pubsub_v1
              ; pubsub_v0
              }
          in
          let net_config =
            { Mina_networking.Config.genesis_ledger_hash
            ; log_gossip_heard
            ; is_seed
            ; creatable_gossip_net =
                Mina_networking.Gossip_net.(
                  Any.Creatable
                    ((module Libp2p), Libp2p.create ~pids gossip_net_params))
            }
          in
          let coinbase_receiver : Consensus.Coinbase_receiver.t =
            Option.value_map coinbase_receiver_flag ~default:`Producer
              ~f:(fun pk -> `Other pk)
          in
          let proposed_protocol_version_opt =
            Mina_run.get_proposed_protocol_version_opt ~conf_dir ~logger
              proposed_protocol_version
          in
          ( match
              (uptime_url_string, uptime_submitter_key, uptime_submitter_pubkey)
            with
          | Some _, Some _, None | Some _, None, Some _ | None, None, None ->
              ()
          | _ ->
              Mina_stdlib.Mina_user_error.raise
                "Must provide both --uptime-url and exactly one of \
                 --uptime-submitter-key or --uptime-submitter-pubkey" ) ;
          let uptime_url =
            Option.map uptime_url_string ~f:(fun s -> Uri.of_string s)
          in
          let uptime_submitter_opt =
            Option.map uptime_submitter_pubkey ~f:(fun s ->
                match Public_key.Compressed.of_base58_check s with
                | Ok pk -> (
                    match Public_key.decompress pk with
                    | Some _ ->
                        pk
                    | None ->
                        failwithf
                          "Invalid public key %s for uptime submitter (could \
                           not decompress)"
                          s () )
                | Error err ->
                    Mina_stdlib.Mina_user_error.raisef
                      "Invalid public key %s for uptime submitter, %s" s
                      (Error.to_string_hum err) () )
          in
          let%bind uptime_submitter_keypair =
            match (uptime_submitter_key, uptime_submitter_opt) with
            | None, None ->
                return None
            | None, Some pk ->
                let%map kp =
                  Secrets.Wallets.get_tracked_keypair ~logger
                    ~which:"uptime submitter keypair"
                    ~read_from_env_exn:
                      (Secrets.Uptime_keypair.Terminal_stdin.read_exn
                         ~should_prompt_user:false ~should_reask:false )
                    ~conf_dir pk
                in
                Some kp
            | Some sk_file, None ->
                let%map kp =
                  Secrets.Uptime_keypair.Terminal_stdin.read_exn
                    ~should_prompt_user:false ~should_reask:false
                    ~which:"uptime submitter keypair" sk_file
                in
                Some kp
            | _ ->
                (* unreachable, because of earlier check *)
                failwith
                  "Cannot provide both uptime submitter public key and uptime \
                   submitter keyfile"
          in
          if itn_features then
            (* set queue bound directly in Itn_logger
               adding bound to Mina_lib config introduces cycle
            *)
            Option.iter itn_max_logs ~f:Itn_logger.set_queue_bound ;
          let start_time = Time.now () in
          let%map mina =
            Mina_lib.create ~commit_id:Mina_version.commit_id ~wallets
              (Mina_lib.Config.make ~logger ~pids ~trust_system ~conf_dir
                 ~file_log_level ~log_level ~log_json ~chain_id
                 ~disable_node_status ~demo_mode ~coinbase_receiver ~net_config
                 ~gossip_net_params ~proposed_protocol_version_opt
                 ~work_selection_method:
                   (Cli_lib.Arg_type.work_selection_method_to_module
                      work_selection_method )
                 ~snark_worker_config:
                   { Mina_lib.Config.Snark_worker_config
                     .initial_snark_worker_key = run_snark_worker_flag
                   ; shutdown_on_disconnect = true
                   ; num_threads = snark_worker_parallelism_flag
                   }
                 ~snark_coordinator_key:run_snark_coordinator_flag
                 ~snark_pool_disk_location:chain_state_locations.snark_pool
                 ~wallets_disk_location:(conf_dir ^/ "wallets")
                 ~persistent_root_location:chain_state_locations.root
                 ~persistent_frontier_location:chain_state_locations.frontier
                 ~epoch_ledger_location
                 ~proof_cache_location:chain_state_locations.proof_cache
                 ~zkapp_vk_cache_location:chain_state_locations.zkapp_vk_cache
                 ~snark_work_fee:snark_work_fee_flag ~time_controller
                 ~block_production_keypairs ~monitor ~consensus_local_state
                 ~is_archive_rocksdb ~work_reassignment_wait
                 ~archive_process_location ~log_block_creation
                 ~precomputed_values ~start_time ?precomputed_blocks_path
                 ~precomputed_blocks_dir ~log_precomputed_blocks
                 ~start_filtered_logs ~upload_blocks_to_gcloud
                 ~block_reward_threshold ~uptime_url ~uptime_submitter_keypair
                 ~uptime_send_node_commit ~stop_time ~stop_time_interval
                 ~node_status_url ~graphql_control_port:itn_graphql_port
                 ~simplified_node_stats
                 ~zkapp_cmd_limit:(ref compile_config.zkapp_cmd_limit)
                 ~itn_features ~compile_config ~hardfork_handling
                 ~ledger_backing () )
          in
          { mina
          ; client_trustlist
          ; rest_server_port
          ; limited_graphql_port
          ; itn_graphql_port
          }
        in
        (* Breaks a dependency cycle with monitor initilization and coda *)
        let mina_ref : Mina_lib.t option ref = ref None in
        Option.iter node_error_url ~f:(fun url ->
            let get_node_state () =
              match !mina_ref with
              | None ->
                  Deferred.return None
              | Some mina ->
                  let%map node_state = Mina_lib.get_node_state mina in
                  Some node_state
            in
            Node_error_service.set_config ~get_node_state
              ~node_error_url:(Uri.of_string url) ~contact_info ) ;
        Mina_run.handle_shutdown ~monitor ~time_controller ~conf_dir
          ~child_pids:pids ~top_logger:logger mina_ref ;
        Async.Scheduler.within' ~monitor
        @@ fun () ->
        let%bind { mina
                 ; client_trustlist
                 ; rest_server_port
                 ; limited_graphql_port
                 ; itn_graphql_port
                 } =
          mina_initialization_deferred ()
        in
        mina_ref := Some mina ;
        (* Start auto hardfork config generation if conditions are met *)
        O1trace.background_thread "auto_hardfork_config_generation" (fun () ->
            Mina_run.start_auto_hardfork_config_generation ~logger mina ) ;
        (*This pipe is consumed only by integration tests*)
        don't_wait_for
          (Pipe_lib.Strict_pipe.Reader.iter_without_pushback
             (Mina_lib.validated_transitions mina)
             ~f:ignore ) ;
        Mina_run.setup_local_server ?client_trustlist ~rest_server_port
          ~insecure_rest_server ~open_limited_graphql_port ?limited_graphql_port
          ?itn_graphql_port ?auth_keys:itn_keys mina ;
        let%bind () =
          Option.map metrics_server_port ~f:(fun port ->
              let forward_uri =
                Option.map libp2p_metrics_port ~f:(fun port ->
                    Uri.with_uri ~scheme:(Some "http") ~host:(Some "127.0.0.1")
                      ~port:(Some port) ~path:(Some "/metrics") Uri.empty )
              in
              Mina_metrics.Runtime.(
                gc_stat_interval_mins :=
                  Option.value ~default:!gc_stat_interval_mins gc_stat_interval) ;
              Mina_metrics.server ?forward_uri ~port ~logger () >>| ignore )
          |> Option.value ~default:Deferred.unit
        in
        return mina )

let daemon logger ~itn_features =
  let compile_config =
    Mina_compile_config.of_node_config (module Node_config)
  in
  Command.async ~summary:"Mina daemon"
    (Command.Param.map
       (setup_daemon logger ~itn_features
          ~default_snark_worker_fee:compile_config.default_snark_worker_fee )
       ~f:(fun setup_daemon () ->
         match%bind
           Monitor.try_with (fun () ->
               (* Immediately disable updating the time offset. *)
               Block_time.Controller.disable_setting_offset () ;
               let%bind mina = setup_daemon () in
               let%map () = Mina_lib.start mina in
               [%log info] "Daemon ready. Clients can now connect" )
         with
         | Ok _ ->
             Async.never ()
         | Error exn ->
             let exn_json =
               Error_json.error_to_yojson (Error.of_exn ~backtrace:`Get exn)
             in
             [%log fatal] "Unhandled Async exception: $exn"
               ~metadata:[ ("exn", exn_json) ] ;
             exit 1 ) )

let replay_blocks logger ~itn_features =
  let replay_flag =
    let open Command.Param in
    flag "--blocks-filename" ~aliases:[ "-blocks-filename" ] (required string)
      ~doc:"PATH The file to read the precomputed blocks from"
  in
  let read_kind =
    let open Command.Param in
    flag "--format" ~aliases:[ "-format" ] (optional string)
      ~doc:"json|sexp The format to read lines of the file in (default: json)"
  in
  let compile_config =
    Mina_compile_config.of_node_config (module Node_config)
  in
  Command.async ~summary:"Start mina daemon with blocks replayed from a file"
    (Command.Param.map3 replay_flag read_kind
       (setup_daemon logger ~itn_features
          ~default_snark_worker_fee:compile_config.default_snark_worker_fee )
       ~f:(fun blocks_filename read_kind setup_daemon () ->
         (* Enable updating the time offset. *)
         Block_time.Controller.enable_setting_offset () ;
         let read_block_line =
           match Option.map ~f:String.lowercase read_kind with
           | Some "json" | None -> (
               fun line ->
                 match
                   Yojson.Safe.from_string line
                   |> Mina_block.Precomputed.of_yojson
                 with
                 | Ok block ->
                     block
                 | Error err ->
                     failwithf "Could not read block: %s" err () )
           | Some "sexp" ->
               fun line ->
                 Sexp.of_string_conv_exn line Mina_block.Precomputed.t_of_sexp
           | _ ->
               failwith "Expected one of 'json', 'sexp' for -format flag"
         in
         let blocks =
           Sequence.unfold ~init:(In_channel.create blocks_filename)
             ~f:(fun blocks_file ->
               match In_channel.input_line blocks_file with
               | Some line ->
                   Some (read_block_line line, blocks_file)
               | None ->
                   In_channel.close blocks_file ;
                   None )
         in
         let%bind mina = setup_daemon () in
         let%bind () = Mina_lib.start_with_precomputed_blocks mina blocks in
         [%log info]
           "Daemon is ready, replayed precomputed blocks. Clients can now \
            connect" ;
         Async.never () ) )

let dump_type_shapes =
  let max_depth_flag =
    let open Command.Param in
    flag "--max-depth" ~aliases:[ "-max-depth" ] (optional int)
      ~doc:"NN Maximum depth of shape S-expressions"
  in
  Command.basic ~summary:"Print serialization shapes of versioned types"
    (Command.Param.map max_depth_flag ~f:(fun max_depth () ->
         Ppx_version_runtime.Shapes.iteri
           ~f:(fun ~key:path ~data:(shape, ty_decl) ->
             let open Bin_prot.Shape in
             let canonical = eval shape in
             let digest = Canonical.to_digest canonical |> Digest.to_hex in
             let shape_summary =
               let shape_sexp =
                 Canonical.to_string_hum canonical |> Sexp.of_string
               in
               (* elide the shape below specified depth, so that changes to
                  contained types aren't considered a change to the containing
                  type, even though the shape digests differ
               *)
               let summary_sexp =
                 match max_depth with
                 | None ->
                     shape_sexp
                 | Some n ->
                     let rec go sexp depth =
                       if depth > n then Sexp.Atom "."
                       else
                         match sexp with
                         | Sexp.Atom _ ->
                             sexp
                         | Sexp.List items ->
                             Sexp.List
                               (List.map items ~f:(fun item ->
                                    go item (depth + 1) ) )
                     in
                     go shape_sexp 0
               in
               Sexp.to_string summary_sexp
             in
             Core_kernel.printf "%s, %s, %s, %s\n" path digest shape_summary
               ty_decl ) ) )

let primitive_ok = function
  | "array" | "bytes" | "string" | "bigstring" ->
      false
  | "int" | "int32" | "int64" | "nativeint" | "char" | "bool" | "float" ->
      true
  | "unit" | "option" | "list" ->
      true
  | "kimchi_backend_bigint_32_V1" ->
      true
  | "Mina_stdlib.Bounded_types.String.t"
  | "Mina_stdlib.Bounded_types.String.Tagged.t"
  | "Mina_stdlib.Bounded_types.Array.t" ->
      true
  | "8fabab0a-4992-11e6-8cca-9ba2c4686d9e" ->
      true (* hashtbl *)
  | "ac8a9ff4-4994-11e6-9a1b-9fb4e933bd9d" ->
      true (* Make_iterable_binable *)
  | s ->
      failwithf "unknown primitive %s" s ()

let audit_type_shapes : Command.t =
  let rec shape_ok (shape : Sexp.t) : bool =
    match shape with
    | List [ Atom "Exp"; exp ] ->
        exp_ok exp
    | List [] ->
        true
    | _ ->
        failwithf "bad shape: %s" (Sexp.to_string shape) ()
  and exp_ok (exp : Sexp.t) : bool =
    match exp with
    | List [ Atom "Base"; Atom tyname; List exps ] ->
        primitive_ok tyname && List.for_all exps ~f:shape_ok
    | List [ Atom "Record"; List fields ] ->
        List.for_all fields ~f:(fun field ->
            match field with
            | List [ Atom _; sh ] ->
                shape_ok sh
            | _ ->
                failwithf "unhandled rec field: %s" (Sexp.to_string_hum field)
                  () )
    | List [ Atom "Tuple"; List exps ] ->
        List.for_all exps ~f:shape_ok
    | List [ Atom "Variant"; List ctors ] ->
        List.for_all ctors ~f:(fun ctor ->
            match ctor with
            | List [ Atom _ctr; List exps ] ->
                List.for_all exps ~f:shape_ok
            | _ ->
                failwithf "unhandled variant: %s" (Sexp.to_string_hum ctor) () )
    | List [ Atom "Poly_variant"; List [ List [ Atom "sorted"; List ctors ] ] ]
      ->
        List.for_all ctors ~f:(fun ctor ->
            match ctor with
            | List [ Atom _ctr ] ->
                true
            | List [ Atom _ctr; List fields ] ->
                List.for_all fields ~f:shape_ok
            | _ ->
                failwithf "unhandled poly variant: %s" (Sexp.to_string_hum ctor)
                  () )
    | List [ Atom "Application"; sh; List args ] ->
        shape_ok sh && List.for_all args ~f:shape_ok
    | List [ Atom "Rec_app"; Atom _; List args ] ->
        List.for_all args ~f:shape_ok
    | List [ Atom "Var"; Atom _ ] ->
        true
    | List (Atom ctr :: _) ->
        failwithf "unhandled ctor (%s) in exp_ok: %s" ctr
          (Sexp.to_string_hum exp) ()
    | List [] | List _ | Atom _ ->
        failwithf "bad format: %s" (Sexp.to_string_hum exp) ()
  in
  let handle_shape (path : string) (shape : Bin_prot.Shape.t) (ty_decl : string)
      (good : int ref) (bad : int ref) =
    let open Bin_prot.Shape in
    let path, file = String.lsplit2_exn ~on:':' path in
    let canonical = eval shape in
    let shape_sexp = Canonical.to_string_hum canonical |> Sexp.of_string in
    if not @@ shape_ok shape_sexp then (
      incr bad ;
      Core.eprintf "%s has a bad shape in %s (%s):\n%s\n" path file ty_decl
        (Canonical.to_string_hum canonical) )
    else incr good
  in
  Command.basic ~summary:"Audit shapes of versioned types"
    (Command.Param.return (fun () ->
         let bad, good = (ref 0, ref 0) in
         Ppx_version_runtime.Shapes.iteri
           ~f:(fun ~key:path ~data:(shape, ty_decl) ->
             handle_shape path shape ty_decl good bad ) ;
         Core.printf "good shapes:\n\t%d\nbad shapes:\n\t%d\n%!" !good !bad ;
         if !bad > 0 then Core.exit 1 ) )

(*NOTE A previous version of this function included compile time ppx that didn't compile, and was never
  evaluated under any build profile
*)
let ensure_testnet_id_still_good _ = Deferred.unit

let snark_hashes =
  let module Hashes = struct
    type t = string list [@@deriving to_yojson]
  end in
  let open Command.Let_syntax in
  Command.basic ~summary:"List hashes of proving and verification keys"
    [%map_open
      let json = Cli_lib.Flag.json in
      fun () -> if json then Core.printf "[]\n%!"]

let internal_commands logger ~itn_features =
  let (module G) = Genesis_constants.profiled () in
  [ ( Snark_worker.Entry.command_name
    , Snark_worker.Entry.command_from_rpcs ~proof_level:G.proof_level
        ~constraint_constants:G.constraint_constants
        ~commit_id:Mina_version.commit_id )
  ; ("snark-hashes", snark_hashes)
  ; ( "run-prover"
    , Command.async
        ~summary:"Run prover on a sexp provided on a single line of stdin"
        (let%map_open.Command signature_kind = Cli_lib.Flag.signature_kind in
         fun () ->
           let logger = Logger.create () in
           let constraint_constants = G.constraint_constants in
           let proof_level = G.proof_level in
           Parallel.init_master () ;
           match%bind Reader.read_sexp (Lazy.force Reader.stdin) with
           | `Ok sexp ->
               let%bind conf_dir = Unix.mkdtemp "/tmp/mina-prover" in
               [%log info] "Prover state being logged to %s" conf_dir ;
               let%bind prover =
                 Prover.create ~commit_id:Mina_version.commit_id ~logger
                   ~proof_level ~constraint_constants
                   ~pids:(Pid.Table.create ()) ~conf_dir ~signature_kind ()
               in
               Prover.prove_from_input_sexp prover sexp >>| ignore
           | `Eof ->
               failwith "early EOF while reading sexp" ) )
  ; ( "run-snark-worker-single"
    , Command.async
        ~summary:"Run snark-worker on a sexp provided on a single line of stdin"
        (let open Command.Let_syntax in
        let%map_open filename =
          flag "--file" (required string)
            ~doc:"File containing the s-expression of the snark work to execute"
        and signature_kind = Cli_lib.Flag.signature_kind in
        fun () ->
          let open Deferred.Let_syntax in
          let logger = Logger.create () in
          let constraint_constants = G.constraint_constants in
          let proof_level = G.proof_level in
          Parallel.init_master () ;
          match%bind
            Reader.with_file filename ~f:(fun reader ->
                [%log info] "Created reader for %s" filename ;
                Reader.read_sexp reader )
          with
          | `Ok sexp -> (
              let%bind worker_state =
                Snark_worker.Impl.Worker_state.create ~proof_level
                  ~constraint_constants ~signature_kind ()
              in
              let sok_message =
                { Mina_base.Sok_message.fee = Currency.Fee.of_mina_int_exn 0
                ; prover = Quickcheck.random_value Public_key.Compressed.gen
                }
              in
              let spec =
                [%of_sexp:
                  ( Transaction_witness.Stable.Latest.t
                  , Ledger_proof.t )
                  Snark_work_lib.Work.Single.Spec.t] sexp
              in
              match%map
                Snark_worker.Impl.perform_single worker_state
                  ~message:sok_message spec
              with
              | Ok _ ->
                  [%log info] "Successfully worked"
              | Error err ->
                  [%log error] "Work didn't work: $err"
                    ~metadata:[ ("err", Error_json.error_to_yojson err) ] )
          | `Eof ->
              failwith "early EOF while reading sexp") )
  ; ( "run-verifier"
    , Command.async
        ~summary:"Run verifier on a proof provided on a single line of stdin"
        (let open Command.Let_syntax in
        let%map_open mode =
          flag "--mode" ~aliases:[ "-mode" ] (required string)
            ~doc:"transaction/blockchain the snark to verify. Defaults to json"
        and format =
          flag "--format" ~aliases:[ "-format" ] (optional string)
            ~doc:"sexp/json the format to parse input in"
        and limit =
          flag "--limit" ~aliases:[ "-limit" ] (optional int)
            ~doc:"limit the number of proofs taken from the file"
        in
        fun () ->
          let open Async in
          let logger = Logger.create () in
          let constraint_constants = G.constraint_constants in
          let proof_level = G.proof_level in
          Parallel.init_master () ;
          let%bind conf_dir = Unix.mkdtemp "/tmp/mina-verifier" in
          let mode =
            match mode with
            | "transaction" ->
                `Transaction
            | "blockchain" ->
                `Blockchain
            | mode ->
                failwithf
                  "Expected mode flag to be one of transaction, blockchain, \
                   got '%s'"
                  mode ()
          in
          let format =
            match format with
            | Some "sexp" ->
                `Sexp
            | Some "json" | None ->
                `Json
            | Some format ->
                failwithf
                  "Expected format flag to be one of sexp, json, got '%s'"
                  format ()
          in
          let%bind input =
            match format with
            | `Sexp -> (
                let%map input_sexp =
                  match%map Reader.read_sexp (Lazy.force Reader.stdin) with
                  | `Ok input_sexp ->
                      input_sexp
                  | `Eof ->
                      failwith "early EOF while reading sexp"
                in
                match mode with
                | `Transaction ->
                    `Transaction
                      (List.t_of_sexp Ledger_proof.t_of_sexp input_sexp)
                | `Blockchain ->
                    `Blockchain
                      (List.t_of_sexp Blockchain_snark.Blockchain.t_of_sexp
                         input_sexp ) )
            | `Json -> (
                let%map input_line =
                  match%map Reader.read_line (Lazy.force Reader.stdin) with
                  | `Ok input_line ->
                      input_line
                  | `Eof ->
                      failwith "early EOF while reading json"
                in
                match mode with
                | `Transaction -> (
                    match
                      [%derive.of_yojson: Ledger_proof.t list]
                        (Yojson.Safe.from_string input_line)
                    with
                    | Ok input ->
                        `Transaction input
                    | Error err ->
                        failwithf "Could not parse JSON: %s" err () )
                | `Blockchain -> (
                    match
                      [%derive.of_yojson: Blockchain_snark.Blockchain.t list]
                        (Yojson.Safe.from_string input_line)
                    with
                    | Ok input ->
                        `Blockchain input
                    | Error err ->
                        failwithf "Could not parse JSON: %s" err () ) )
          in

          let%bind verifier =
            Verifier.For_tests.default ~constraint_constants ~proof_level
              ~commit_id:Mina_version.commit_id ~logger
              ~pids:(Pid.Table.create ()) ~conf_dir:(Some conf_dir) ()
          in
          let%bind result =
            let cap lst =
              Option.value_map ~default:Fn.id ~f:(Fn.flip List.take) limit lst
            in
            match input with
            | `Transaction input ->
                input |> cap |> Verifier.verify_transaction_snarks verifier
            | `Blockchain input ->
                input |> cap |> Verifier.verify_blockchain_snarks verifier
          in
          match result with
          | Ok (Ok ()) ->
              printf "Proofs verified successfully" ;
              exit 0
          | Ok (Error err) ->
              printf "Proofs failed to verify:\n%s\n"
                (Yojson.Safe.pretty_to_string (Error_json.error_to_yojson err)) ;
              exit 1
          | Error err ->
              printf "Failed while verifying proofs:\n%s"
                (Error.to_string_hum err) ;
              exit 2) )
  ; ( "dump-structured-events"
    , Command.async ~summary:"Dump the registered structured events"
        (let open Command.Let_syntax in
        let%map outfile =
          Core_kernel.Command.Param.flag "--out-file" ~aliases:[ "-out-file" ]
            (Core_kernel.Command.Flag.optional Core_kernel.Command.Param.string)
            ~doc:"FILENAME File to output to. Defaults to stdout"
        and pretty =
          Core_kernel.Command.Param.flag "--pretty" ~aliases:[ "-pretty" ]
            Core_kernel.Command.Param.no_arg
            ~doc:"  Set to output 'pretty' JSON"
        in
        fun () ->
          let out_channel =
            match outfile with
            | Some outfile ->
                Core_kernel.Out_channel.create outfile
            | None ->
                Core_kernel.Out_channel.stdout
          in
          let json =
            Structured_log_events.dump_registered_events ()
            |> [%derive.to_yojson:
                 (string * Structured_log_events.id * string list) list]
          in
          if pretty then Yojson.Safe.pretty_to_channel out_channel json
          else Yojson.Safe.to_channel out_channel json ;
          ( match outfile with
          | Some _ ->
              Core_kernel.Out_channel.close out_channel
          | None ->
              () ) ;
          Deferred.return ()) )
  ; ("dump-type-shapes", dump_type_shapes)
  ; ("replay-blocks", replay_blocks logger ~itn_features)
  ; ("audit-type-shapes", audit_type_shapes)
  ; ( "test-genesis-block-generation"
    , Command.async ~summary:"Generate a genesis proof"
        (let open Command.Let_syntax in
        let%map_open config_files =
          flag "--config-file" ~aliases:[ "config-file" ]
            ~doc:
              "PATH path to a configuration file (overrides MINA_CONFIG_FILE, \
               default: <config_dir>/daemon.json). Pass multiple times to \
               override fields from earlier config files"
            (listed string)
        and conf_dir = Cli_lib.Flag.conf_dir
        and genesis_dir =
          flag "--genesis-ledger-dir" ~aliases:[ "genesis-ledger-dir" ]
            ~doc:
              "DIR Directory that contains the genesis ledger and the genesis \
               blockchain proof (default: <config-dir>)"
            (optional string)
        and signature_kind = Cli_lib.Flag.signature_kind in
        fun () ->
          let open Deferred.Let_syntax in
          Parallel.init_master () ;
          let logger = Logger.create () in
          let conf_dir = Mina_lib.Conf_dir.compute_conf_dir_exn conf_dir in
          let genesis_constants = G.genesis_constants in
          let constraint_constants = G.constraint_constants in
          let proof_level = Genesis_constants.Proof_level.Full in
          let config_files =
            List.map config_files ~f:(fun config_file ->
                (config_file, `Must_exist) )
          in
          let%bind ( precomputed_values
                   , _config_jsons
                   , _config
                   , _chain_state_locations
                   , _
                   , _ ) =
            load_config_files ~logger ~conf_dir ~genesis_dir ~genesis_constants
              ~constraint_constants ~proof_level ~cli_proof_level:None
              ~hardfork_handling:Keep_running config_files
          in
          let pids = Child_processes.Termination.create_pid_table () in
          let%bind prover =
            (* We create a prover process (unnecessarily) here, to have a more
               realistic test.
            *)
            Prover.create ~commit_id:Mina_version.commit_id ~logger ~pids
              ~conf_dir ~proof_level
              ~constraint_constants:precomputed_values.constraint_constants
              ~signature_kind ()
          in
          match%bind
            Prover.create_genesis_block prover
              (Genesis_proof.to_inputs precomputed_values)
          with
          | Ok block ->
              Format.eprintf "Generated block@.%s@."
                ( Yojson.Safe.to_string
                @@ Blockchain_snark.Blockchain.to_yojson block ) ;
              exit 0
          | Error err ->
              Format.eprintf "Failed to generate block@.%s@."
                (Yojson.Safe.to_string @@ Error_json.error_to_yojson err) ;
              exit 1) )
  ; ( "chain-id"
    , Command.async
        ~summary:"Print the chain_id that uniquely identifies the network"
        (let open Command.Let_syntax in
        let%map_open config_files =
          flag "--config-file" ~aliases:[ "config-file" ]
            ~doc:
              "PATH path to a configuration file (overrides MINA_CONFIG_FILE, \
               default: <config_dir>/daemon.json). Pass multiple times to \
               override fields from earlier config files"
            (listed string)
        and conf_dir = Cli_lib.Flag.conf_dir
        and genesis_dir =
          flag "--genesis-ledger-dir" ~aliases:[ "genesis-ledger-dir" ]
            ~doc:"DIR Directory that contains the genesis ledger"
            (optional string)
        and from_config_hashes_only =
          flag "--from-config-hashes-only"
            ~aliases:[ "from-config-hashes-only" ]
            ~doc:
              "Compute chain_id using only the hashes in the config file, \
               without requiring unpacked ledger data"
            no_arg
        in
        fun () ->
          let open Deferred.Let_syntax in
          Parallel.init_master () ;
          let logger = Logger.create () in
          let conf_dir = Mina_lib.Conf_dir.compute_conf_dir_exn conf_dir in

          let (module G) = Genesis_constants.profiled () in
          let genesis_constants = G.genesis_constants in
          let constraint_constants = G.constraint_constants in
          let proof_level = Genesis_constants.Proof_level.Full in
          if from_config_hashes_only then (
            let%bind config =
              Deferred.List.filter_map config_files ~f:(fun config_file ->
                  match%map
                    Genesis_ledger_helper.load_config_json config_file
                  with
                  | Ok config_json -> (
                      match Runtime_config.of_yojson config_json with
                      | Ok config ->
                          Some config
                      | Error err ->
                          failwithf "Could not parse configuration file %s: %s"
                            config_file err () )
                  | Error err ->
                      Error.raise err )
              >>| List.fold ~init:Runtime_config.default
                    ~f:Runtime_config.combine
            in
            match
              Init.Chain_state_locations.chain_id_of_config ~logger
                ~signature_kind:Mina_signature_kind.t_DEPRECATED ~proof_level
                ~genesis_constants ~constraint_constants config
            with
            | Some chain_id ->
                printf "%s" (Chain_id.to_string chain_id) ;
                exit 0
            | None ->
                eprintf
                  "Could not compute chain_id from config hashes. Ensure the \
                   config contains ledger.hash and epoch_data hashes.\n" ;
                exit 1 )
          else
            let config_files =
              List.map config_files ~f:(fun config_file ->
                  (config_file, `Must_exist) )
            in
            let%bind ( _
                     , _config_jsons
                     , config
                     , _chain_state_locations
                     , _
                     , chain_id ) =
              load_config_files ~logger ~conf_dir ~genesis_dir
                ~genesis_constants ~constraint_constants ~proof_level
                ~cli_proof_level:None ~hardfork_handling:Keep_running
                config_files
            in
            let chain_id = Lazy.force chain_id in
            match
              Init.Chain_state_locations.chain_id_of_config ~logger
                ~signature_kind:Mina_signature_kind.t_DEPRECATED ~proof_level
                ~genesis_constants ~constraint_constants config
            with
            | None ->
                let () = printf "%s" (Chain_id.to_string chain_id) in
                exit 0
            | Some chain_id_from_config ->
                if not (Chain_id.equal chain_id_from_config chain_id) then
                  failwithf "Chain_id mismatch %s /= %s"
                    Chain_id.(to_string chain_id_from_config)
                    (Chain_id.to_string chain_id)
                    ()
                else
                  let () = printf "%s" (Chain_id.to_string chain_id) in
                  exit 0) )
  ; ( "print-hard-fork-genesis-timestamp"
    , Command.async
        ~summary:
          "Print the scheduled hard fork genesis timestamp computed from the \
           given config file(s)"
        (let open Command.Let_syntax in
        let%map_open config_files =
          flag "--config-file" ~aliases:[ "config-file" ]
            ~doc:
              "PATH path to a configuration file. Pass multiple times to \
               override fields from earlier config files"
            (listed string)
        in
        fun () ->
          let open Deferred.Let_syntax in
          let logger = Logger.null () in
          let (module G) = Genesis_constants.profiled () in
          let genesis_constants = G.genesis_constants in
          let constraint_constants = G.constraint_constants in
          let proof_level = G.proof_level in
          let config =
            let config_jsons =
              List.map config_files ~f:(fun config_file ->
                  let json =
                    In_channel.with_file config_file ~f:(fun ic ->
                        Yojson.Safe.from_channel ic )
                  in
                  (config_file, json) )
            in
            List.fold ~init:Runtime_config.default config_jsons
              ~f:(fun config (config_file, config_json) ->
                match Runtime_config.of_yojson config_json with
                | Ok loaded_config ->
                    Runtime_config.combine config loaded_config
                | Error err ->
                    failwithf "Could not parse configuration file %s: %s"
                      config_file err () )
          in
          let scheduled_genesis_slot =
            match Runtime_config.scheduled_hard_fork_genesis_slot config with
            | Some slot ->
                slot
            | None ->
                failwith
                  "Could not compute scheduled genesis slot: slot_chain_end \
                   and hard_fork_genesis_slot_delta must both be set in the \
                   daemon config"
          in
          let%map light_proof =
            match%map
              Genesis_ledger_helper.light_proof_from_runtime_config ~logger
                ~cli_proof_level:None ~genesis_constants ~constraint_constants
                ~proof_level config
            with
            | Ok light_proof ->
                light_proof
            | Error err ->
                Error.raise err
          in
          let consensus_constants = light_proof.consensus_constants in
          let timestamp =
            Consensus.Data.Consensus_time.(
              start_time ~constants:consensus_constants
                (of_global_slot ~constants:consensus_constants
                   scheduled_genesis_slot ))
            |> Block_time.to_time_exn
            |> Time.to_string_iso8601_basic ~zone:Time.Zone.utc
          in
          print_endline timestamp) )
  ]

let mina_commands logger ~itn_features =
  [ ("accounts", Client.accounts)
  ; ("daemon", daemon logger ~itn_features)
  ; ("client", Client.client)
  ; ("advanced", Client.advanced ~itn_features)
  ; ("ledger", Client.ledger)
  ; ("libp2p", Client.libp2p)
  ; ( "internal"
    , Command.group ~summary:"Internal commands"
        (internal_commands logger ~itn_features) )
  ; (Parallel.worker_command_name, Parallel.worker_command)
  ; ("transaction-snark-profiler", Transaction_snark_profiler.command)
  ]

let print_version_help coda_exe version =
  (* mimic Jane Street command help *)
  let lines =
    [ "print version information"
    ; ""
    ; sprintf "  %s %s" (Filename.basename coda_exe) version
    ; ""
    ; "=== flags ==="
    ; ""
    ; "  [-help]  print this help text and exit"
    ; "           (alias: -?)"
    ]
  in
  List.iter lines ~f:(Core.printf "%s\n%!")

let print_version_info () = Core.printf "Commit %s\n" Mina_version.commit_id

let () =
  try
    Random.self_init () ;
    let itn_features = Sys.getenv "ITN_FEATURES" |> Option.is_some in
    let logger = Logger.create ~itn_features () in
    don't_wait_for (ensure_testnet_id_still_good logger) ;
    (* Turn on snark debugging in prod for now *)
    Snarky_backendless.Snark.set_eval_constraints true ;
    (* intercept command-line processing for "version", because we don't
       use the Jane Street scripts that generate their version information
    *)
    (let is_version_cmd s =
       List.mem [ "version"; "-version"; "--version" ] s ~equal:String.equal
     in
     match Sys.get_argv () with
     | [| _mina_exe; version |] when is_version_cmd version ->
         Mina_version.print_version ()
     | _ ->
         Command.run
           (Command.group ~summary:"Mina" ~preserve_subcommand_order:()
              (mina_commands logger ~itn_features) ) ) ;
    Core.exit 0
  with exn ->
    let logger = Logger.create () in
    let exn_json =
      Error_json.error_to_yojson (Error.of_exn ~backtrace:`Get exn)
    in
    [%log fatal] "Unhandled top level exception: $exn"
      ~metadata:[ ("exn", exn_json) ]

let linkme = ()
