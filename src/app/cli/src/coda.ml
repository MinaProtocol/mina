[%%import
"/src/config.mlh"]

open Core
open Async
open Coda_base
open Cli_lib
open Signature_lib
open Init
module YJ = Yojson.Safe

[%%check_ocaml_word_size
64]

[%%if
record_async_backtraces]

let () = Async.Scheduler.set_record_backtraces true

[%%endif]

let chain_id ~genesis_state_hash ~genesis_constants =
  let genesis_state_hash = State_hash.to_base58_check genesis_state_hash in
  let genesis_constants_hash = Genesis_constants.hash genesis_constants in
  let all_snark_keys = String.concat ~sep:"" Precomputed_values.key_hashes in
  let b2 =
    Blake2.digest_string
      (genesis_state_hash ^ all_snark_keys ^ genesis_constants_hash)
  in
  Blake2.to_hex b2

[%%inject
"daemon_expiry", daemon_expiry]

[%%inject
"compile_time_current_protocol_version", current_protocol_version]

[%%if
plugins]

let plugin_flag =
  let open Command.Param in
  flag "load-plugin" (listed string)
    ~doc:
      "PATH The path to load a .cmxs plugin from. May be passed multiple times"

[%%else]

let plugin_flag = Command.Param.return []

[%%endif]

let daemon logger =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  Command.async ~summary:"Coda daemon"
    (let%map_open conf_dir = Cli_lib.Flag.conf_dir
     and block_production_key =
       flag "block-producer-key"
         ~doc:
           "KEYFILE Private key file for the block producer. You cannot \
            provide both `block-producer-key` and `block-producer-pubkey`. \
            (default: don't produce blocks)"
         (optional string)
     and block_production_pubkey =
       flag "block-producer-pubkey"
         ~doc:
           "PUBLICKEY Public key for the associated private key that is being \
            tracked by this daemon. You cannot provide both \
            `block-producer-key` and `block-producer-pubkey`. (default: don't \
            produce blocks)"
         (optional public_key_compressed)
     and block_production_password =
       flag "block-producer-password"
         ~doc:
           "PASSWORD Password associated with the block-producer key. Setting \
            this is equivalent to setting the CODA_PRIVKEY_PASS environment \
            variable. Be careful when setting it in the commandline as it \
            will likely get tracked in your history. Mainly to be used from \
            the daemon.json config file"
         (optional string)
     and demo_mode =
       flag "demo-mode" no_arg
         ~doc:
           "Run the daemon in demo-mode -- assume we're \"synced\" to the \
            network instantly"
     and coinbase_receiver_flag =
       flag "coinbase-receiver"
         ~doc:
           "PUBLICKEY Address to send coinbase rewards to (if this node is \
            producing blocks). If not provided, coinbase rewards will be sent \
            to the producer of a block."
         (optional public_key_compressed)
     and genesis_dir =
       flag "genesis-ledger-dir"
         ~doc:
           "DIR Directory that contains the genesis ledger and the genesis \
            blockchain proof (default: <config-dir>)"
         (optional string)
     and run_snark_worker_flag =
       flag "run-snark-worker"
         ~doc:"PUBLICKEY Run the SNARK worker with this public key"
         (optional public_key_compressed)
     and run_snark_coordinator_flag =
       flag "run-snark-coordinator"
         ~doc:
           "PUBLICKEY Run a SNARK coordinator with this public key (ignored \
            if the run-snark-worker is set)"
         (optional public_key_compressed)
     and snark_worker_parallelism_flag =
       flag "snark-worker-parallelism"
         ~doc:
           "NUM Run the SNARK worker using this many threads. Equivalent to \
            setting OMP_NUM_THREADS, but doesn't affect block production."
         (optional int)
     and work_selection_method_flag =
       flag "work-selection"
         ~doc:
           "seq|rand Choose work sequentially (seq) or randomly (rand) \
            (default: rand)"
         (optional work_selection_method)
     and libp2p_port = Flag.Port.Daemon.external_
     and client_port = Flag.Port.Daemon.client
     and rest_server_port = Flag.Port.Daemon.rest_server
     and archive_process_location = Flag.Host_and_port.Daemon.archive
     and metrics_server_port =
       flag "metrics-port"
         ~doc:
           "PORT metrics server for scraping via Prometheus (default no \
            metrics-server)"
         (optional int16)
     and external_ip_opt =
       flag "external-ip"
         ~doc:
           "IP External IP address for other nodes to connect to. You only \
            need to set this if auto-discovery fails for some reason."
         (optional string)
     and bind_ip_opt =
       flag "bind-ip"
         ~doc:"IP IP of network interface to use for peer connections"
         (optional string)
     and working_dir =
       flag "working-dir"
         ~doc:
           "PATH path to chdir into before starting (useful for background \
            mode, defaults to cwd, or / if -background)"
         (optional string)
     and is_background =
       flag "background" no_arg ~doc:"Run process on the background"
     and is_archive_rocksdb =
       flag "archive-rocksdb" no_arg
         ~doc:"Stores all the blocks heard in RocksDB"
     and log_json = Flag.Log.json
     and log_level = Flag.Log.level
     and snark_work_fee =
       flag "snark-worker-fee"
         ~doc:
           (sprintf
              "FEE Amount a worker wants to get compensated for generating a \
               snark proof (default: %d)"
              (Currency.Fee.to_int Coda_compile_config.default_snark_worker_fee))
         (optional txn_fee)
     and work_reassignment_wait =
       flag "work-reassignment-wait" (optional int)
         ~doc:
           (sprintf
              "WAIT-TIME in ms before a snark-work is reassigned (default: \
               %dms)"
              Cli_lib.Default.work_reassignment_wait)
     and enable_tracing =
       flag "tracing" no_arg ~doc:"Trace into $config-directory/$pid.trace"
     and insecure_rest_server =
       flag "insecure-rest-server" no_arg
         ~doc:
           "Have REST server listen on all addresses, not just localhost \
            (this is INSECURE, make sure your firewall is configured \
            correctly!)"
     (* FIXME #4095
     and limit_connections =
       flag "limit-concurrent-connections"
         ~doc:
           "true|false Limit the number of concurrent connections per IP \
            address (default: true)"
         (optional bool)*)
     (*TODO: This is being added to log all the snark works received for the
     beta-testnet challenge. We might want to remove this later?*)
     and log_received_snark_pool_diff =
       flag "log-snark-work-gossip"
         ~doc:
           "true|false Log snark-pool diff received from peers (default: false)"
         (optional bool)
     and log_received_blocks =
       flag "log-received-blocks"
         ~doc:"true|false Log blocks received from peers (default: false)"
         (optional bool)
     and log_transaction_pool_diff =
       flag "log-txn-pool-gossip"
         ~doc:
           "true|false Log transaction-pool diff received from peers \
            (default: false)"
         (optional bool)
     and log_block_creation =
       flag "log-block-creation"
         ~doc:
           "true|false Log the steps involved in including transactions and \
            snark work in a block (default: true)"
         (optional bool)
     and libp2p_keypair =
       flag "discovery-keypair" (optional string)
         ~doc:
           "KEYFILE Keypair (generated from `coda advanced \
            generate-libp2p-keypair`) to use with libp2p discovery (default: \
            generate per-run temporary keypair)"
     and is_seed = flag "seed" ~doc:"Start the node as a seed node" no_arg
     and enable_flooding =
       flag "enable-flooding"
         ~doc:
           "Enable pubsub flooding, gossiping every message to every peer \
            (uses lots of bandwidth! default: false)"
         no_arg
     and libp2p_peers_raw =
       flag "peer"
         ~doc:
           "/ip4/IPADDR/tcp/PORT/p2p/PEERID initial \"bootstrap\" peers for \
            discovery"
         (listed string)
     and curr_protocol_version =
       flag "current-protocol-version" (optional string)
         ~doc:
           "NN.NN.NN Current protocol version, only blocks with the same \
            version accepted"
     and proposed_protocol_version =
       flag "proposed-protocol-version" (optional string)
         ~doc:"NN.NN.NN Proposed protocol version to signal other nodes"
     and config_file =
       flag "config-file"
         ~doc:
           "PATH path to the configuration file (overrides CODA_CONFIG_FILE, \
            default: <config_dir>/daemon.json)"
         (optional string)
     and may_generate =
       flag "generate-genesis-proof"
         ~doc:
           "true|false Generate a new genesis proof for the current \
            configuration if none is found (default: false)"
         (optional bool)
     and disable_telemetry =
       flag "disable-telemetry" no_arg
         ~doc:"Disable reporting telemetry to other nodes"
     and proof_level =
       flag "proof-level"
         (optional (Arg_type.create Genesis_constants.Proof_level.of_string))
         ~doc:"full|check|none"
     and plugins = plugin_flag in
     fun () ->
       let open Deferred.Let_syntax in
       let compute_conf_dir home =
         Option.value ~default:(home ^/ Cli_lib.Default.conf_dir_name) conf_dir
       in
       let%bind conf_dir =
         if is_background then
           let home = Core.Sys.home_directory () in
           let conf_dir = compute_conf_dir home in
           Deferred.return conf_dir
         else Sys.home_directory () >>| compute_conf_dir
       in
       let%bind () = File_system.create_dir conf_dir in
       let () =
         if is_background then (
           Core.printf "Starting background coda daemon. (Log Dir: %s)\n%!"
             conf_dir ;
           Daemon.daemonize ~redirect_stdout:`Dev_null ?cd:working_dir
             ~redirect_stderr:`Dev_null () )
         else ignore (Option.map working_dir ~f:Caml.Sys.chdir)
       in
       Stdout_log.setup log_json log_level ;
       (* 512MB logrotate max size = 1GB max filesystem usage *)
       let logrotate_max_size = 1024 * 1024 * 512 in
       Logger.Consumer_registry.register ~id:"default"
         ~processor:(Logger.Processor.raw ())
         ~transport:
           (Logger.Transport.File_system.dumb_logrotate ~directory:conf_dir
              ~log_filename:"coda.log" ~max_size:logrotate_max_size) ;
       [%log info]
         "Coda daemon is booting up; built with commit $commit on branch \
          $branch"
         ~metadata:
           [ ("commit", `String Coda_version.commit_id)
           ; ("branch", `String Coda_version.branch) ] ;
       if not @@ String.equal daemon_expiry "never" then (
         [%log info] "Daemon will expire at $exp"
           ~metadata:[("exp", `String daemon_expiry)] ;
         let tm =
           (* same approach as in Genesis_constants.genesis_state_timestamp *)
           let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
           Core.Time.of_string_gen
             ~if_no_timezone:(`Use_this_one default_timezone) daemon_expiry
         in
         Clock.run_at tm
           (fun () ->
             [%log info] "Daemon has expired, shutting down" ;
             Core.exit 0 )
           () ) ;
       [%log info] "Booting may take several seconds, please wait" ;
       let%bind libp2p_keypair =
         let libp2p_keypair_old_format =
           Option.bind libp2p_keypair ~f:(fun s ->
               match Coda_net2.Keypair.of_string s with
               | Ok kp ->
                   Some kp
               | Error _ ->
                   if String.contains s ',' then
                     [%log warn]
                       "I think -discovery-keypair is in the old format, but \
                        I failed to parse it! Using it as a path..." ;
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
               Secrets.Libp2p_keypair.Terminal_stdin.read_exn s
               |> Deferred.map ~f:Option.some )
       in
       (* Check if the config files are for the current version.
        * WARNING: Deleting ALL the files in the config directory if there is
        * a version mismatch *)
       (* When persistence is added back, this needs to be revisited
        * to handle persistence related files properly *)
       let%bind () =
         let make_version ~wipe_dir =
           let%bind () =
             if wipe_dir then File_system.clear_dir conf_dir else Deferred.unit
           in
           let%bind wr = Writer.open_file (conf_dir ^/ "coda.version") in
           Writer.write_line wr Coda_version.commit_id ;
           Writer.close wr
         in
         match%bind
           Monitor.try_with_or_error (fun () ->
               let%bind r = Reader.open_file (conf_dir ^/ "coda.version") in
               match%map Pipe.to_list (Reader.lines r) with
               | [] ->
                   ""
               | s ->
                   List.hd_exn s )
         with
         | Ok c ->
             if String.equal c Coda_version.commit_id then return ()
             else (
               [%log warn]
                 "Different version of Coda detected in config directory \
                  $config_directory, removing existing configuration"
                 ~metadata:[("config_directory", `String conf_dir)] ;
               make_version ~wipe_dir:true )
         | Error e ->
             [%log trace]
               ~metadata:[("error", `String (Error.to_string_mach e))]
               "Error reading coda.version: $error" ;
             [%log debug]
               "Failed to read coda.version, cleaning up the config directory \
                $config_directory"
               ~metadata:[("config_directory", `String conf_dir)] ;
             make_version ~wipe_dir:false
       in
       Memory_stats.log_memory_stats logger ~process:"daemon" ;
       Parallel.init_master () ;
       let monitor = Async.Monitor.create ~name:"coda" () in
       let module Coda_initialization = struct
         type ('a, 'b, 'c) t =
           {coda: 'a; client_trustlist: 'b; rest_server_port: 'c}
       end in
       let time_controller =
         Block_time.Controller.create @@ Block_time.Controller.basic ~logger
       in
       let may_generate = Option.value ~default:false may_generate in
       let coda_initialization_deferred () =
         let config_file, must_find_config_file =
           match config_file with
           | Some config_file ->
               (config_file, true)
           | None -> (
             match Sys.getenv "CODA_CONFIG_FILE" with
             | Some config_file ->
                 (config_file, false)
             | None ->
                 (conf_dir ^/ "daemon.json", false) )
         in
         let%bind config_json =
           match%map Genesis_ledger_helper.load_config_json config_file with
           | Ok config ->
               Some config
           | Error err when must_find_config_file ->
               [%log fatal]
                 "Failed reading configuration from $config_file: $error"
                 ~metadata:
                   [ ("config_file", `String config_file)
                   ; ("error", `String (Error.to_string_hum err)) ] ;
               Error.raise err
           | Error err ->
               [%log warn]
                 "Failed reading configuration from $config_file: $error"
                 ~metadata:
                   [ ("config_file", `String config_file)
                   ; ("error", `String (Error.to_string_hum err)) ] ;
               None
         in
         let%bind config_json =
           match config_json with
           | Some config_json ->
               let%map config_json =
                 Genesis_ledger_helper.upgrade_old_config ~logger config_file
                   config_json
               in
               Some config_json
           | None ->
               return None
         in
         let config =
           match config_json with
           | Some config_json -> (
             match Runtime_config.of_yojson config_json with
             | Ok config ->
                 config
             | Error err ->
                 [%log fatal]
                   "Could not parse configuration from $config_file: $error"
                   ~metadata:
                     [ ("config_file", `String config_file)
                     ; ("config_json", config_json)
                     ; ("error", `String err) ] ;
                 failwithf "Could not parse configuration: %s" err () )
           | _ ->
               Runtime_config.default
         in
         let genesis_dir = Option.value ~default:conf_dir genesis_dir in
         let%bind precomputed_values =
           match%map
             Genesis_ledger_helper.init_from_config_file ~genesis_dir ~logger
               ~may_generate ~proof_level config
           with
           | Ok (precomputed_values, _) ->
               precomputed_values
           | Error err ->
               [%log fatal]
                 "Failed initializing with configuration $config: $error"
                 ~metadata:
                   [ ("config", Runtime_config.to_yojson config)
                   ; ("error", `String (Error.to_string_hum err)) ] ;
               Error.raise err
         in
         let daemon_config =
           Option.bind config_json ~f:(fun config_json ->
               YJ.Util.(to_option Fn.id (YJ.Util.member "daemon" config_json))
           )
         in
         let maybe_from_config (type a) (f : YJ.t -> a option)
             (keyname : string) (actual_value : a option) : a option =
           let open Option.Let_syntax in
           let open YJ.Util in
           match actual_value with
           | Some v ->
               Some v
           | None ->
               let%bind daemon_config = daemon_config in
               let%bind json_val =
                 to_option Fn.id (member keyname daemon_config)
               in
               [%log debug] "Key $key being used from config file"
                 ~metadata:[("key", `String keyname)] ;
               f json_val
         in
         let or_from_config map keyname actual_value ~default =
           match maybe_from_config map keyname actual_value with
           | Some x ->
               x
           | None ->
               [%log trace]
                 "Key '$key' not found in the config file, using default"
                 ~metadata:[("key", `String keyname)] ;
               default
         in
         let get_port {Flag.Types.value; default; name} =
           or_from_config YJ.Util.to_int_option name ~default value
         in
         let libp2p_port = get_port libp2p_port in
         let rest_server_port = get_port rest_server_port in
         let client_port = get_port client_port in
         let snark_work_fee_flag =
           let json_to_currency_fee_option json =
             YJ.Util.to_int_option json |> Option.map ~f:Currency.Fee.of_int
           in
           or_from_config json_to_currency_fee_option "snark-worker-fee"
             ~default:Coda_compile_config.default_snark_worker_fee
             snark_work_fee
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
                (Fn.compose work_selection_method_val YJ.Util.to_string))
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
         let log_received_blocks =
           or_from_config YJ.Util.to_bool_option "log-received-blocks"
             ~default:false log_received_blocks
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
           { Coda_networking.Config.snark_pool_diff=
               log_received_snark_pool_diff
           ; transaction_pool_diff= log_transaction_pool_diff
           ; new_state= log_received_blocks }
         in
         let json_to_publickey_compressed_option json =
           YJ.Util.to_string_option json
           |> Option.bind ~f:(fun pk_str ->
                  match Public_key.Compressed.of_base58_check pk_str with
                  | Ok key ->
                      Some key
                  | Error e ->
                      [%log error] "Error decoding public key ($key): $error"
                        ~metadata:
                          [ ("key", `String pk_str)
                          ; ("error", `String (Error.to_string_hum e)) ] ;
                      None )
         in
         let run_snark_worker_flag =
           maybe_from_config json_to_publickey_compressed_option
             "run-snark-worker" run_snark_worker_flag
         in
         let run_snark_coordinator_flag =
           maybe_from_config json_to_publickey_compressed_option
             "run-snark-coordinator" run_snark_coordinator_flag
         in
         let snark_worker_parallelism_flag =
           maybe_from_config YJ.Util.to_int_option "snark-worker-parallelism"
             snark_worker_parallelism_flag
         in
         let coinbase_receiver_flag =
           maybe_from_config json_to_publickey_compressed_option
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
           {external_ip; bind_ip; peer= None; client_port; libp2p_port}
         in
         let block_production_key =
           maybe_from_config YJ.Util.to_string_option "block-producer-key"
             block_production_key
         in
         let block_production_pubkey =
           maybe_from_config json_to_publickey_compressed_option
             "block-producer-pubkey" block_production_pubkey
         in
         let block_production_password =
           maybe_from_config YJ.Util.to_string_option "block-producer-password"
             block_production_password
         in
         Option.iter
           ~f:(fun password ->
             match Sys.getenv Secrets.Keypair.env with
             | Some env_pass when env_pass <> password ->
                 [%log warn]
                   "$envkey environment variable doesn't match value provided \
                    on command-line or daemon.json. Using value from $envkey"
                   ~metadata:[("envkey", `String Secrets.Keypair.env)]
             | _ ->
                 Unix.putenv ~key:Secrets.Keypair.env ~data:password )
           block_production_password ;
         let%bind block_production_keypair =
           match (block_production_key, block_production_pubkey) with
           | Some _, Some _ ->
               eprintf
                 "Error: You cannot provide both `block-producer-key` and \
                  `block_production_pubkey`\n" ;
               exit 11
           | None, None ->
               Deferred.return None
           | Some sk_file, _ ->
               let%map kp = Secrets.Keypair.Terminal_stdin.read_exn sk_file in
               Some kp
           | _, Some tracked_pubkey ->
               let%bind wallets =
                 Secrets.Wallets.load ~logger
                   ~disk_location:(conf_dir ^/ "wallets")
               in
               let sk_file = Secrets.Wallets.get_path wallets tracked_pubkey in
               let%map kp = Secrets.Keypair.Terminal_stdin.read_exn sk_file in
               Some kp
         in
         let%bind client_trustlist =
           Reader.load_sexp
             (conf_dir ^/ "client_trustlist")
             [%of_sexp: Unix.Cidr.t list]
           >>| Or_error.ok
         in
         let client_trustlist =
           match Unix.getenv "CODA_CLIENT_TRUSTLIST" with
           | Some envstr ->
               let cidrs =
                 String.split ~on:',' envstr |> List.map ~f:Unix.Cidr.of_string
               in
               Some
                 (List.append cidrs (Option.value ~default:[] client_trustlist))
           | None ->
               client_trustlist
         in
         Stream.iter
           (Async.Scheduler.long_cycles
              ~at_least:(sec 0.5 |> Time_ns.Span.of_span_float_round_nearest))
           ~f:(fun span ->
             let secs = Time_ns.Span.to_sec span in
             [%log debug]
               ~metadata:[("long_async_cycle", `Float secs)]
               "Long async cycle, $long_async_cycle seconds" ;
             Coda_metrics.(
               Runtime.Long_async_histogram.observe Runtime.long_async_cycle
                 secs) ) ;
         Stream.iter
           Async_kernel.Async_kernel_scheduler.(long_jobs_with_context @@ t ())
           ~f:(fun (context, span) ->
             let secs = Time_ns.Span.to_sec span in
             [%log debug]
               ~metadata:
                 [ ("long_async_job", `Float secs)
                 ; ( "most_recent_2_backtrace"
                   , `String
                       (String.concat ~sep:"␤"
                          (List.map ~f:Backtrace.to_string
                             (List.take
                                (Execution_context.backtrace_history context)
                                2))) ) ]
               "Long async job, $long_async_job seconds" ;
             Coda_metrics.(
               Runtime.Long_job_histogram.observe Runtime.long_async_job secs)
             ) ;
         let trace_database_initialization typ location =
           (* can't use %log ppx here, because we're using the passed-in location *)
           Logger.trace logger ~module_:__MODULE__ "Creating %s at %s"
             ~location typ
         in
         let trust_dir = conf_dir ^/ "trust" in
         let%bind () = Async.Unix.mkdir ~p:() trust_dir in
         let trust_system = Trust_system.create trust_dir in
         trace_database_initialization "trust_system" __LOC__ trust_dir ;
         let genesis_state_hash =
           Precomputed_values.genesis_state_hash precomputed_values
         in
         let genesis_ledger_hash =
           Precomputed_values.genesis_ledger precomputed_values
           |> Lazy.force |> Ledger.merkle_root
         in
         let initial_block_production_keypairs =
           block_production_keypair |> Option.to_list |> Keypair.Set.of_list
         in
         let consensus_local_state =
           Consensus.Data.Local_state.create
             ~genesis_ledger:
               (Precomputed_values.genesis_ledger precomputed_values)
             ( Option.map block_production_keypair ~f:(fun keypair ->
                   let open Keypair in
                   Public_key.compress keypair.public_key )
             |> Option.to_list |> Public_key.Compressed.Set.of_list )
         in
         trace_database_initialization "consensus local state" __LOC__
           trust_dir ;
         let initial_peers =
           List.concat
             [ List.map ~f:Coda_net2.Multiaddr.of_string libp2p_peers_raw
             ; List.map ~f:Coda_net2.Multiaddr.of_string
               @@ or_from_config
                    (Fn.compose Option.some
                       (YJ.Util.convert_each YJ.Util.to_string))
                    "peers" None ~default:[] ]
         in
         if enable_tracing then Coda_tracing.start conf_dir |> don't_wait_for ;
         if is_seed then [%log info] "Starting node as a seed node"
         else if List.is_empty initial_peers then
           failwith "no seed or initial peer flags passed" ;
         let gossip_net_params =
           Gossip_net.Libp2p.Config.
             { timeout= Time.Span.of_sec 3.
             ; logger
             ; conf_dir
             ; chain_id=
                 chain_id ~genesis_state_hash
                   ~genesis_constants:precomputed_values.genesis_constants
             ; unsafe_no_trust_ip= false
             ; initial_peers
             ; addrs_and_ports
             ; trust_system
             ; flood= enable_flooding
             ; keypair= libp2p_keypair }
         in
         let net_config =
           { Coda_networking.Config.logger
           ; trust_system
           ; time_controller
           ; consensus_local_state
           ; genesis_ledger_hash
           ; constraint_constants= precomputed_values.constraint_constants
           ; log_gossip_heard
           ; is_seed
           ; creatable_gossip_net=
               Coda_networking.Gossip_net.(
                 Any.Creatable
                   ((module Libp2p), Libp2p.create gossip_net_params)) }
         in
         let receipt_chain_dir_name = conf_dir ^/ "receipt_chain" in
         let%bind () = Async.Unix.mkdir ~p:() receipt_chain_dir_name in
         let receipt_chain_database =
           Receipt_chain_database.create receipt_chain_dir_name
         in
         trace_database_initialization "receipt_chain_database" __LOC__
           receipt_chain_dir_name ;
         let transaction_database_dir = conf_dir ^/ "transaction" in
         let%bind () = Async.Unix.mkdir ~p:() transaction_database_dir in
         let transaction_database =
           Auxiliary_database.Transaction_database.create ~logger
             transaction_database_dir
         in
         trace_database_initialization "transaction_database" __LOC__
           transaction_database_dir ;
         let external_transition_database_dir =
           conf_dir ^/ "external_transition_database"
         in
         let%bind () =
           Async.Unix.mkdir ~p:() external_transition_database_dir
         in
         let external_transition_database =
           Auxiliary_database.External_transition_database.create ~logger
             external_transition_database_dir
         in
         trace_database_initialization "external_transition_database" __LOC__
           external_transition_database_dir ;
         (* log terminated child processes *)
         (* FIXME adapt to new system, move into child_processes lib *)
         let pids = Child_processes.Termination.create_pid_table () in
         let rec terminated_child_loop () =
           match
             try Unix.wait_nohang `Any
             with
             | Unix.Unix_error (errno, _, _)
             when Int.equal (Unix.Error.compare errno Unix.ECHILD) 0
                  (* no child processes exist *)
             ->
               None
           with
           | None ->
               (* no children have terminated, wait to check again *)
               let%bind () = Async.after (Time.Span.of_min 1.) in
               terminated_child_loop ()
           | Some (child_pid, exit_or_signal) ->
               let child_pid_metadata =
                 [("child_pid", `Int (Pid.to_int child_pid))]
               in
               ( match exit_or_signal with
               | Ok () ->
                   [%log info]
                     "Daemon child process $child_pid terminated with exit \
                      code 0"
                     ~metadata:child_pid_metadata
               | Error err -> (
                 match err with
                 | `Signal signal ->
                     [%log info]
                       "Daemon child process $child_pid terminated after \
                        receiving signal $signal"
                       ~metadata:
                         ( ("signal", `String (Signal.to_string signal))
                         :: child_pid_metadata )
                 | `Exit_non_zero exit_code ->
                     [%log info]
                       "Daemon child process $child_pid terminated with \
                        nonzero exit code $exit_code"
                       ~metadata:
                         (("exit_code", `Int exit_code) :: child_pid_metadata)
                 ) ) ;
               (* terminate daemon if children registered *)
               Child_processes.Termination.check_terminated_child pids
                 child_pid logger ;
               (* check for other terminated children, without waiting *)
               terminated_child_loop ()
         in
         O1trace.trace_task "terminated child loop" terminated_child_loop ;
         let coinbase_receiver =
           Option.value_map coinbase_receiver_flag ~default:`Producer
             ~f:(fun pk -> `Other pk)
         in
         let current_protocol_version =
           Coda_run.get_current_protocol_version
             ~compile_time_current_protocol_version ~conf_dir ~logger
             curr_protocol_version
         in
         let proposed_protocol_version_opt =
           Coda_run.get_proposed_protocol_version_opt ~conf_dir ~logger
             proposed_protocol_version
         in
         let%map coda =
           Coda_lib.create
             (Coda_lib.Config.make ~logger ~pids ~trust_system ~conf_dir
                ~is_seed ~disable_telemetry ~demo_mode ~coinbase_receiver
                ~net_config ~gossip_net_params
                ~initial_protocol_version:current_protocol_version
                ~proposed_protocol_version_opt
                ~work_selection_method:
                  (Cli_lib.Arg_type.work_selection_method_to_module
                     work_selection_method)
                ~snark_worker_config:
                  { Coda_lib.Config.Snark_worker_config.initial_snark_worker_key=
                      run_snark_worker_flag
                  ; shutdown_on_disconnect= true
                  ; num_threads= snark_worker_parallelism_flag }
                ~snark_coordinator_key:run_snark_coordinator_flag
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~wallets_disk_location:(conf_dir ^/ "wallets")
                ~persistent_root_location:(conf_dir ^/ "root")
                ~persistent_frontier_location:(conf_dir ^/ "frontier")
                ~snark_work_fee:snark_work_fee_flag ~receipt_chain_database
                ~time_controller ~initial_block_production_keypairs ~monitor
                ~consensus_local_state ~transaction_database
                ~external_transition_database ~is_archive_rocksdb
                ~work_reassignment_wait ~archive_process_location
                ~log_block_creation ~precomputed_values ())
         in
         {Coda_initialization.coda; client_trustlist; rest_server_port}
       in
       (* Breaks a dependency cycle with monitor initilization and coda *)
       let coda_ref : Coda_lib.t option ref = ref None in
       Coda_run.handle_shutdown ~monitor ~time_controller ~conf_dir
         ~top_logger:logger coda_ref ;
       Async.Scheduler.within' ~monitor
       @@ fun () ->
       let%bind {Coda_initialization.coda; client_trustlist; rest_server_port}
           =
         coda_initialization_deferred ()
       in
       coda_ref := Some coda ;
       (*This pipe is consumed only by integration tests*)
       don't_wait_for
         (Pipe_lib.Strict_pipe.Reader.iter_without_pushback
            (Coda_lib.validated_transitions coda)
            ~f:ignore) ;
       Coda_run.setup_local_server ?client_trustlist ~rest_server_port
         ~insecure_rest_server coda ;
       let%bind () = Coda_lib.start coda in
       let%bind () =
         Option.map metrics_server_port ~f:(fun port ->
             Coda_metrics.server ~port ~logger >>| ignore )
         |> Option.value ~default:Deferred.unit
       in
       let () = Coda_plugins.init_plugins ~logger coda plugins in
       [%log info] "Daemon ready. Clients can now connect" ;
       Async.never ())

[%%if
force_updates]

let rec ensure_testnet_id_still_good logger =
  let open Cohttp_async in
  let recheck_soon = 0.1 in
  let recheck_later = 1.0 in
  let try_later hrs =
    Async.Clock.run_after (Time.Span.of_hr hrs)
      (fun () -> don't_wait_for @@ ensure_testnet_id_still_good logger)
      ()
  in
  let soon_minutes = Int.of_float (60.0 *. recheck_soon) in
  match%bind
    Monitor.try_with_or_error (fun () ->
        Client.get (Uri.of_string "http://updates.o1test.net/testnet_id") )
  with
  | Error e ->
      [%log error]
        "Exception while trying to fetch testnet_id: $error. Trying again in \
         $retry_minutes minutes"
        ~metadata:
          [ ("error", `String (Error.to_string_hum e))
          ; ("retry_minutes", `Int soon_minutes) ] ;
      try_later recheck_soon ;
      Deferred.unit
  | Ok (resp, body) -> (
      if resp.status <> `OK then (
        [%log error]
          "HTTP response status $HTTP_status while getting testnet id, \
           checking again in $retry_minutes minutes."
          ~metadata:
            [ ( "HTTP_status"
              , `String (Cohttp.Code.string_of_status resp.status) )
            ; ("retry_minutes", `Int soon_minutes) ] ;
        try_later recheck_soon ;
        Deferred.unit )
      else
        let%bind body_string = Body.to_string body in
        let valid_ids =
          String.split ~on:'\n' body_string
          |> List.map ~f:(Fn.compose Git_sha.of_string String.strip)
        in
        (* Maybe the Git_sha.of_string is a bit gratuitous *)
        let finish local_id remote_ids =
          let str x = Git_sha.sexp_of_t x |> Sexp.to_string in
          eprintf
            "The version for the testnet has changed, and this client \
             (version %s) is no longer compatible. Please download the latest \
             Coda software!\n\
             Valid versions:\n\
             %s\n"
            ( local_id |> Option.map ~f:str
            |> Option.value ~default:"[COMMIT_SHA1 not set]" )
            remote_ids ;
          exit 13
        in
        match commit_id with
        | None ->
            finish None body_string
        | Some sha ->
            if
              List.exists valid_ids ~f:(fun remote_id ->
                  Git_sha.equal sha remote_id )
            then ( try_later recheck_later ; Deferred.unit )
            else finish commit_id body_string )

[%%else]

let ensure_testnet_id_still_good _ = Deferred.unit

[%%endif]

let snark_hashes =
  let module Hashes = struct
    type t = string list [@@deriving to_yojson]
  end in
  let open Command.Let_syntax in
  Command.basic ~summary:"List hashes of proving and verification keys"
    [%map_open
      let json = Cli_lib.Flag.json in
      let print = Core.printf "%s\n%!" in
      fun () ->
        if json then
          print
            (Yojson.Safe.to_string
               (Hashes.to_yojson Precomputed_values.key_hashes))
        else List.iter Precomputed_values.key_hashes ~f:print]

let internal_commands =
  [ (Snark_worker.Intf.command_name, Snark_worker.command)
  ; ("snark-hashes", snark_hashes)
  ; ( "run-prover"
    , Command.async
        ~summary:"Run prover on a sexp provided on a single line of stdin"
        (Command.Param.return (fun () ->
             let logger = Logger.create () in
             Parallel.init_master () ;
             match%bind Reader.read_sexp (Lazy.force Reader.stdin) with
             | `Ok sexp ->
                 let%bind conf_dir = Unix.mkdtemp "/tmp/coda-prover" in
                 [%log info] "Prover state being logged to %s" conf_dir ;
                 let%bind prover =
                   Prover.create ~logger
                     ~proof_level:Genesis_constants.Proof_level.compiled
                     ~constraint_constants:
                       Genesis_constants.Constraint_constants.compiled
                     ~pids:(Pid.Table.create ()) ~conf_dir
                 in
                 Prover.prove_from_input_sexp prover sexp >>| ignore
             | `Eof ->
                 failwith "early EOF while reading sexp" )) )
  ; ( "dump-structured-events"
    , Command.async ~summary:"Dump the registered structured events"
        (let open Command.Let_syntax in
        let%map outfile =
          Core_kernel.Command.Param.flag "-out-file"
            (Core_kernel.Command.Flag.optional Core_kernel.Command.Param.string)
            ~doc:"FILENAME File to output to. Defaults to stdout"
        and pretty =
          Core_kernel.Command.Param.flag "-pretty"
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
          Deferred.return ()) ) ]

let coda_commands logger =
  [ ("accounts", Client.accounts)
  ; ("daemon", daemon logger)
  ; ("client", Client.client)
  ; ("advanced", Client.advanced)
  ; ("internal", Command.group ~summary:"Internal commands" internal_commands)
  ; (Parallel.worker_command_name, Parallel.worker_command)
  ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]

[%%if
integration_tests]

module type Integration_test = sig
  val name : string

  val command : Async.Command.t
end

let coda_commands logger =
  let open Tests in
  let group =
    List.map
      ~f:(fun (module T) -> (T.name, T.command))
      ( [ (module Coda_peers_test)
        ; (module Coda_block_production_test)
        ; (module Coda_shared_state_test)
        ; (module Coda_transitive_peers_test)
        ; (module Coda_shared_prefix_test)
        ; (module Coda_shared_prefix_multiproducer_test)
        ; (module Coda_five_nodes_test)
        ; (module Coda_restart_node_test)
        ; (module Coda_receipt_chain_test)
        ; (module Coda_restarts_and_txns_holy_grail)
        ; (module Coda_bootstrap_test)
        ; (module Coda_batch_payment_test)
        ; (module Coda_long_fork)
        ; (module Coda_txns_and_restart_non_producers)
        ; (module Coda_delegation_test)
        ; (module Coda_change_snark_worker_test)
        ; (module Full_test)
        ; (module Transaction_snark_profiler)
        ; (module Coda_archive_node_test)
        ; (module Coda_archive_processor_test) ]
        : (module Integration_test) list )
  in
  coda_commands logger
  @ [("integration-tests", Command.group ~summary:"Integration tests" group)]

[%%endif]

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
    ; "           (alias: -?)" ]
  in
  List.iter lines ~f:(Core.printf "%s\n%!")

let print_version_info () =
  Core.printf "Commit %s on branch %s\n"
    (String.sub Coda_version.commit_id ~pos:0 ~len:7)
    Coda_version.branch

let () =
  Random.self_init () ;
  let logger = Logger.create () in
  don't_wait_for (ensure_testnet_id_still_good logger) ;
  (* Turn on snark debugging in prod for now *)
  Snarky_backendless.Snark.set_eval_constraints true ;
  (* intercept command-line processing for "version", because we don't
     use the Jane Street scripts that generate their version information
   *)
  (let make_list_mem ss s = List.mem ss s ~equal:String.equal in
   let is_version_cmd = make_list_mem ["version"; "-version"] in
   let is_help_flag = make_list_mem ["-help"; "-?"] in
   match Sys.argv with
   | [|_coda_exe; version|] when is_version_cmd version ->
       print_version_info ()
   | [|coda_exe; version; help|]
     when is_version_cmd version && is_help_flag help ->
       print_version_help coda_exe version
   | _ ->
       Command.run
         (Command.group ~summary:"Coda" ~preserve_subcommand_order:()
            (coda_commands logger))) ;
  Core.exit 0
