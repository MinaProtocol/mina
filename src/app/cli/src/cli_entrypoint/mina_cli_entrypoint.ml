[%%import "/src/config.mlh"]

open Core
open Async
open Mina_base
open Cli_lib
open Signature_lib
open Init
module YJ = Yojson.Safe

[%%if record_async_backtraces]

let () = Async.Scheduler.set_record_backtraces true

[%%endif]

type mina_initialization =
  { mina : Mina_lib.t
  ; client_trustlist : Unix.Cidr.t list option
  ; rest_server_port : int
  ; limited_graphql_port : int option
  ; itn_graphql_port : int option
  }

let chain_id ~constraint_system_digests ~genesis_state_hash ~genesis_constants
    ~protocol_major_version =
  (* if this changes, also change Mina_commands.chain_id_inputs *)
  let genesis_state_hash = State_hash.to_base58_check genesis_state_hash in
  let genesis_constants_hash = Genesis_constants.hash genesis_constants in
  let all_snark_keys =
    List.map constraint_system_digests ~f:(fun (_, digest) -> Md5.to_hex digest)
    |> String.concat ~sep:""
  in
  let protocol_version_digest =
    Int.to_string protocol_major_version |> Md5.digest_string |> Md5.to_hex
  in
  let b2 =
    Blake2.digest_string
      ( genesis_state_hash ^ all_snark_keys ^ genesis_constants_hash
      ^ protocol_version_digest )
  in
  Blake2.to_hex b2

[%%inject "daemon_expiry", daemon_expiry]

[%%inject "compile_time_current_protocol_version", current_protocol_version]

[%%if plugins]

let plugin_flag =
  let open Command.Param in
  flag "--load-plugin" ~aliases:[ "load-plugin" ] (listed string)
    ~doc:
      "PATH The path to load a .cmxs plugin from. May be passed multiple times"

[%%else]

let plugin_flag = Command.Param.return []

[%%endif]

let setup_daemon logger =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  let receiver_key_warning = Cli_lib.Default.receiver_key_warning in
  let%map_open conf_dir = Cli_lib.Flag.conf_dir
  and block_production_key =
    flag "--block-producer-key" ~aliases:[ "block-producer-key" ]
      ~doc:
        (sprintf
           "KEYFILE Private key file for the block producer. You cannot \
            provide both `block-producer-key` and `block-producer-pubkey`. \
            (default: don't produce blocks). %s"
           receiver_key_warning )
      (optional string)
  and block_production_pubkey =
    flag "--block-producer-pubkey"
      ~aliases:[ "block-producer-pubkey" ]
      ~doc:
        (sprintf
           "PUBLICKEY Public key for the associated private key that is being \
            tracked by this daemon. You cannot provide both \
            `block-producer-key` and `block-producer-pubkey`. (default: don't \
            produce blocks). %s"
           receiver_key_warning )
      (optional public_key_compressed)
  and block_production_password =
    flag "--block-producer-password"
      ~aliases:[ "block-producer-password" ]
      ~doc:
        "PASSWORD Password associated with the block-producer key. Setting \
         this is equivalent to setting the MINA_PRIVKEY_PASS environment \
         variable. Be careful when setting it in the commandline as it will \
         likely get tracked in your history. Mainly to be used from the \
         daemon.json config file"
      (optional string)
  and itn_keys =
    if Mina_compile_config.itn_features then
      flag "--itn-keys" ~aliases:[ "itn-keys" ] (optional string)
        ~doc:
          "PUBLICKEYS A comma-delimited list of Ed25519 public keys that are \
           permitted to send signed requests to the incentivized testnet \
           GraphQL server"
    else Command.Param.return None
  and itn_max_logs =
    if Mina_compile_config.itn_features then
      flag "--itn-max-logs" ~aliases:[ "itn-max-logs" ] (optional int)
        ~doc:
          "NN Maximum number of logs to store to be made available via GraphQL \
           for incentivized testnet"
    else Command.Param.return None
  and demo_mode =
    flag "--demo-mode" ~aliases:[ "demo-mode" ] no_arg
      ~doc:
        "Run the daemon in demo-mode -- assume we're \"synced\" to the network \
         instantly"
  and coinbase_receiver_flag =
    flag "--coinbase-receiver" ~aliases:[ "coinbase-receiver" ]
      ~doc:
        (sprintf
           "PUBLICKEY Address to send coinbase rewards to (if this node is \
            producing blocks). If not provided, coinbase rewards will be sent \
            to the producer of a block. %s"
           receiver_key_warning )
      (optional public_key_compressed)
  and genesis_dir =
    flag "--genesis-ledger-dir" ~aliases:[ "genesis-ledger-dir" ]
      ~doc:
        "DIR Directory that contains the genesis ledger and the genesis \
         blockchain proof (default: <config-dir>)"
      (optional string)
  and run_snark_worker_flag =
    flag "--run-snark-worker" ~aliases:[ "run-snark-worker" ]
      ~doc:
        (sprintf "PUBLICKEY Run the SNARK worker with this public key. %s"
           receiver_key_warning )
      (optional public_key_compressed)
  and run_snark_coordinator_flag =
    flag "--run-snark-coordinator"
      ~aliases:[ "run-snark-coordinator" ]
      ~doc:
        (sprintf
           "PUBLICKEY Run a SNARK coordinator with this public key (ignored if \
            the run-snark-worker is set). %s"
           receiver_key_warning )
      (optional public_key_compressed)
  and snark_worker_parallelism_flag =
    flag "--snark-worker-parallelism"
      ~aliases:[ "snark-worker-parallelism" ]
      ~doc:
        "NUM Run the SNARK worker using this many threads. Equivalent to \
         setting OMP_NUM_THREADS, but doesn't affect block production."
      (optional int)
  and work_selection_method_flag =
    flag "--work-selection" ~aliases:[ "work-selection" ]
      ~doc:
        "seq|rand Choose work sequentially (seq) or randomly (rand) (default: \
         rand)"
      (optional work_selection_method)
  and libp2p_port = Flag.Port.Daemon.external_
  and client_port = Flag.Port.Daemon.client
  and rest_server_port = Flag.Port.Daemon.rest_server
  and limited_graphql_port = Flag.Port.Daemon.limited_graphql_server
  and itn_graphql_port =
    if Mina_compile_config.itn_features then
      flag "--itn-graphql-port" ~aliases:[ "itn-graphql-port" ]
        ~doc:"PORT GraphQL-server for incentivized testnet interaction"
        (optional int)
    else Command.Param.return None
  and open_limited_graphql_port =
    flag "--open-limited-graphql-port"
      ~aliases:[ "open-limited-graphql-port" ]
      no_arg
      ~doc:
        "Have the limited GraphQL server listen on all addresses, not just \
         localhost (this is INSECURE, make sure your firewall is configured \
         correctly!)"
  and archive_process_location = Flag.Host_and_port.Daemon.archive
  and metrics_server_port =
    flag "--metrics-port" ~aliases:[ "metrics-port" ]
      ~doc:
        "PORT metrics server for scraping via Prometheus (default no \
         metrics-server)"
      (optional int16)
  and gc_stat_interval =
    flag "--gc-stat-interval" ~aliases:[ "gc-stat-interval" ] (optional float)
      ~doc:
        (sprintf
           "INTERVAL in mins for collecting GC stats for metrics (Default: %f)"
           !Mina_metrics.Runtime.gc_stat_interval_mins )
  and libp2p_metrics_port =
    flag "--libp2p-metrics-port" ~aliases:[ "libp2p-metrics-port" ]
      ~doc:
        "PORT libp2p metrics server for scraping via Prometheus (default no \
         libp2p-metrics-server)"
      (optional int16)
  and external_ip_opt =
    flag "--external-ip" ~aliases:[ "external-ip" ]
      ~doc:
        "IP External IP address for other nodes to connect to. You only need \
         to set this if auto-discovery fails for some reason."
      (optional string)
  and bind_ip_opt =
    flag "--bind-ip" ~aliases:[ "bind-ip" ]
      ~doc:"IP IP of network interface to use for peer connections"
      (optional string)
  and working_dir =
    flag "--working-dir" ~aliases:[ "working-dir" ]
      ~doc:
        "PATH path to chdir into before starting (useful for background mode, \
         defaults to cwd, or / if -background)"
      (optional string)
  and is_background =
    flag "--background" ~aliases:[ "background" ] no_arg
      ~doc:"Run process on the background"
  and is_archive_rocksdb =
    flag "--archive-rocksdb" ~aliases:[ "archive-rocksdb" ] no_arg
      ~doc:"Stores all the blocks heard in RocksDB"
  and log_json = Flag.Log.json
  and log_level = Flag.Log.level
  and file_log_level = Flag.Log.file_log_level
  and file_log_rotations = Flag.Log.file_log_rotations
  and snark_work_fee =
    flag "--snark-worker-fee" ~aliases:[ "snark-worker-fee" ]
      ~doc:
        (sprintf
           "FEE Amount a worker wants to get compensated for generating a \
            snark proof (default: %d)"
           (Currency.Fee.to_nanomina_int Currency.Fee.default_snark_worker_fee) )
      (optional txn_fee)
  and work_reassignment_wait =
    flag "--work-reassignment-wait"
      ~aliases:[ "work-reassignment-wait" ]
      (optional int)
      ~doc:
        (sprintf
           "WAIT-TIME in ms before a snark-work is reassigned (default: %dms)"
           Cli_lib.Default.work_reassignment_wait )
  and enable_tracing =
    flag "--tracing" ~aliases:[ "tracing" ] no_arg
      ~doc:"Trace into $config-directory/trace/$pid.trace"
  and enable_internal_tracing =
    flag "--internal-tracing" ~aliases:[ "internal-tracing" ] no_arg
      ~doc:
        "Enables internal tracing into \
         $config-directory/internal-tracing/internal-trace.jsonl"
  and insecure_rest_server =
    flag "--insecure-rest-server" ~aliases:[ "insecure-rest-server" ] no_arg
      ~doc:
        "Have REST server listen on all addresses, not just localhost (this is \
         INSECURE, make sure your firewall is configured correctly!)"
  (* FIXME #4095
     and limit_connections =
       flag "--limit-concurrent-connections"
         ~aliases:[ "limit-concurrent-connections"]
         ~doc:
           "true|false Limit the number of concurrent connections per IP \
            address (default: true)"
         (optional bool)*)
  (*TODO: This is being added to log all the snark works received for the
     beta-testnet challenge. We might want to remove this later?*)
  and log_received_snark_pool_diff =
    flag "--log-snark-work-gossip"
      ~aliases:[ "log-snark-work-gossip" ]
      ~doc:"true|false Log snark-pool diff received from peers (default: false)"
      (optional bool)
  and log_transaction_pool_diff =
    flag "--log-txn-pool-gossip" ~aliases:[ "log-txn-pool-gossip" ]
      ~doc:
        "true|false Log transaction-pool diff received from peers (default: \
         false)"
      (optional bool)
  and log_block_creation =
    flag "--log-block-creation" ~aliases:[ "log-block-creation" ]
      ~doc:
        "true|false Log the steps involved in including transactions and snark \
         work in a block (default: true)"
      (optional bool)
  and libp2p_keypair =
    flag "--libp2p-keypair" ~aliases:[ "libp2p-keypair" ] (required string)
      ~doc:
        "KEYFILE Keypair (generated from `mina libp2p generate-keypair`) to \
         use with libp2p discovery"
  and is_seed =
    flag "--seed" ~aliases:[ "seed" ] ~doc:"Start the node as a seed node"
      no_arg
  and no_super_catchup =
    flag "--no-super-catchup" ~aliases:[ "no-super-catchup" ]
      ~doc:"Don't use super-catchup" no_arg
  and enable_flooding =
    flag "--enable-flooding" ~aliases:[ "enable-flooding" ]
      ~doc:
        "true|false Publish our own blocks/transactions to every peer we can \
         find (default: false)"
      (optional bool)
  and peer_exchange =
    flag "--enable-peer-exchange" ~aliases:[ "enable-peer-exchange" ]
      ~doc:
        "true|false Help keep the mesh connected when closing connections \
         (default: false)"
      (optional bool)
  and peer_protection_ratio =
    flag "--peer-protection-rate" ~aliases:[ "peer-protection-rate" ]
      ~doc:"float Proportion of peers to be marked as protected (default: 0.2)"
      (optional_with_default 0.2 float)
  and min_connections =
    flag "--min-connections" ~aliases:[ "min-connections" ]
      ~doc:
        (Printf.sprintf
           "NN min number of connections that this peer will have to neighbors \
            in the gossip network (default: %d)"
           Cli_lib.Default.min_connections )
      (optional int)
  and max_connections =
    flag "--max-connections" ~aliases:[ "max-connections" ]
      ~doc:
        (Printf.sprintf
           "NN max number of connections that this peer will have to neighbors \
            in the gossip network. Tuning this higher will strengthen your \
            connection to the network in exchange for using more RAM (default: \
            %d)"
           Cli_lib.Default.max_connections )
      (optional int)
  and validation_queue_size =
    flag "--validation-queue-size"
      ~aliases:[ "validation-queue-size" ]
      ~doc:
        (Printf.sprintf
           "NN size of the validation queue in the p2p network used to buffer \
            messages (like blocks and transactions received on the gossip \
            network) while validation is pending. If a transaction, for \
            example, is invalid, we don't forward the message on the gossip \
            net. If this queue is too small, we will drop messages without \
            validating them. If it is too large, we are susceptible to DoS \
            attacks on memory. (default: %d)"
           Cli_lib.Default.validation_queue_size )
      (optional int)
  and direct_peers_raw =
    flag "--direct-peer" ~aliases:[ "direct-peer" ]
      ~doc:
        "/ip4/IPADDR/tcp/PORT/p2p/PEERID Peers to always send new messages \
         to/from. These peers should also have you configured as a direct \
         peer, the relationship is intended to be symmetric"
      (listed string)
  and isolate =
    flag "--isolate-network" ~aliases:[ "isolate-network" ]
      ~doc:
        "true|false Only allow connections to the peers passed on the command \
         line or configured through GraphQL. (default: false)"
      (optional bool)
  and libp2p_peers_raw =
    flag "--peer" ~aliases:[ "peer" ]
      ~doc:
        "/ip4/IPADDR/tcp/PORT/p2p/PEERID initial \"bootstrap\" peers for \
         discovery"
      (listed string)
  and libp2p_peer_list_file =
    flag "--peer-list-file" ~aliases:[ "peer-list-file" ]
      ~doc:
        "PATH path to a file containing \"bootstrap\" peers for discovery, one \
         multiaddress per line"
      (optional string)
  and seed_peer_list_url =
    flag "--peer-list-url" ~aliases:[ "peer-list-url" ]
      ~doc:"URL URL of seed peer list file. Will be polled periodically."
      (optional string)
  and curr_protocol_version =
    flag "--current-protocol-version"
      ~aliases:[ "current-protocol-version" ]
      (optional string)
      ~doc:
        "NN.NN.NN Current protocol version, only blocks with the same version \
         accepted"
  and proposed_protocol_version =
    flag "--proposed-protocol-version"
      ~aliases:[ "proposed-protocol-version" ]
      (optional string)
      ~doc:"NN.NN.NN Proposed protocol version to signal other nodes"
  and config_files =
    flag "--config-file" ~aliases:[ "config-file" ]
      ~doc:
        "PATH path to a configuration file (overrides MINA_CONFIG_FILE, \
         default: <config_dir>/daemon.json). Pass multiple times to override \
         fields from earlier config files"
      (listed string)
  and _may_generate =
    flag "--generate-genesis-proof"
      ~aliases:[ "generate-genesis-proof" ]
      ~doc:"true|false Deprecated. Passing this flag has no effect"
      (optional bool)
  and disable_node_status =
    flag "--disable-node-status" ~aliases:[ "disable-node-status" ] no_arg
      ~doc:"Disable reporting node status to other nodes (default: enabled)"
  and proof_level =
    flag "--proof-level" ~aliases:[ "proof-level" ]
      (optional (Arg_type.create Genesis_constants.Proof_level.of_string))
      ~doc:
        "full|check|none Internal, for testing. Start or connect to a network \
         with full proving (full), snark-testing with dummy proofs (check), or \
         dummy proofs (none)"
  and plugins = plugin_flag
  and precomputed_blocks_path =
    flag "--precomputed-blocks-file"
      ~aliases:[ "precomputed-blocks-file" ]
      (optional string)
      ~doc:"PATH Path to write precomputed blocks to, for replay or archiving"
  and log_precomputed_blocks =
    flag "--log-precomputed-blocks"
      ~aliases:[ "log-precomputed-blocks" ]
      (optional_with_default false bool)
      ~doc:"true|false Include precomputed blocks in the log (default: false)"
  and block_reward_threshold =
    flag "--minimum-block-reward" ~aliases:[ "minimum-block-reward" ]
      ~doc:
        "AMOUNT Minimum reward a block produced by the node should have. Empty \
         blocks are created if the rewards are lower than the specified \
         threshold (default: No threshold, transactions and coinbase will be \
         included as long as the required snark work is available and can be \
         paid for)"
      (optional txn_amount)
  and stop_time =
    flag "--stop-time" ~aliases:[ "stop-time" ] (optional int)
      ~doc:
        (sprintf
           "UPTIME in hours after which the daemon stops itself (only if there \
            were no slots won within an hour after the stop time) (Default: \
            %d)"
           Cli_lib.Default.stop_time )
  and upload_blocks_to_gcloud =
    flag "--upload-blocks-to-gcloud"
      ~aliases:[ "upload-blocks-to-gcloud" ]
      (optional_with_default false bool)
      ~doc:
        "true|false upload blocks to gcloud storage. Requires the environment \
         variables GCLOUD_KEYFILE, NETWORK_NAME, and \
         GCLOUD_BLOCK_UPLOAD_BUCKET"
  and all_peers_seen_metric =
    flag "--all-peers-seen-metric"
      ~aliases:[ "all-peers-seen-metric" ]
      (optional_with_default false bool)
      ~doc:
        "true|false whether to track the set of all peers ever seen for the \
         all_peers metric (default: false)"
  and node_status_url =
    flag "--node-status-url" ~aliases:[ "node-status-url" ] (optional string)
      ~doc:"URL of the node status collection service"
  and node_error_url =
    flag "--node-error-url" ~aliases:[ "node-error-url" ] (optional string)
      ~doc:"URL of the node error collection service"
  and contact_info =
    flag "--contact-info" ~aliases:[ "contact-info" ] (optional string)
      ~doc:
        "contact info used in node error report service (it could be either \
         email address or discord username), it should be less than 200 \
         characters"
    |> Command.Param.map ~f:(fun opt ->
           Option.value_map opt ~default:None ~f:(fun s ->
               if String.length s < 200 then Some s
               else
                 Mina_user_error.raisef
                   "The length of contact info exceeds 200 characters:\n %s" s ) )
  and uptime_url_string =
    flag "--uptime-url" ~aliases:[ "uptime-url" ] (optional string)
      ~doc:"URL URL of the uptime service of the Mina delegation program"
  and uptime_submitter_key =
    flag "--uptime-submitter-key" ~aliases:[ "uptime-submitter-key" ]
      ~doc:
        "KEYFILE Private key file for the uptime submitter. You cannot provide \
         both `uptime-submitter-key` and `uptime-submitter-pubkey`."
      (optional string)
  and uptime_submitter_pubkey =
    flag "--uptime-submitter-pubkey"
      ~aliases:[ "uptime-submitter-pubkey" ]
      (optional string)
      ~doc:
        "PUBLICKEY Public key of the submitter to the Mina delegation program, \
         for the associated private key that is being tracked by this daemon. \
         You cannot provide both `uptime-submitter-key` and \
         `uptime-submitter-pubkey`."
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
    O1trace.thread "mina" (fun () ->
        let open Deferred.Let_syntax in
        let conf_dir = Mina_lib.Conf_dir.compute_conf_dir conf_dir in
        let%bind () = File_system.create_dir conf_dir in
        let () =
          if is_background then (
            Core.printf "Starting background mina daemon. (Log Dir: %s)\n%!"
              conf_dir ;
            Daemon.daemonize ~allow_threads_to_have_been_created:true
              ~redirect_stdout:`Dev_null ?cd:working_dir
              ~redirect_stderr:`Dev_null () )
          else ignore (Option.map working_dir ~f:Caml.Sys.chdir)
        in
        Stdout_log.setup log_json log_level ;
        (* 512MB logrotate max size = 1GB max filesystem usage *)
        let logrotate_max_size = 1024 * 1024 * 10 in
        Logger.Consumer_registry.register ~id:Logger.Logger_id.mina
          ~processor:(Logger.Processor.raw ~log_level:file_log_level ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina.log" ~max_size:logrotate_max_size
               ~num_rotate:file_log_rotations ) ;
        let best_tip_diff_log_size = 1024 * 1024 * 5 in
        Logger.Consumer_registry.register ~id:Logger.Logger_id.best_tip_diff
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina-best-tip.log"
               ~max_size:best_tip_diff_log_size ~num_rotate:1 ) ;
        let rejected_blocks_log_size = 1024 * 1024 * 5 in
        Logger.Consumer_registry.register ~id:Logger.Logger_id.rejected_blocks
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina-rejected-blocks.log"
               ~max_size:rejected_blocks_log_size ~num_rotate:50 ) ;
        Logger.Consumer_registry.register ~id:Logger.Logger_id.oversized_logs
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:conf_dir
               ~log_filename:"mina-oversized-logs.log"
               ~max_size:logrotate_max_size ~num_rotate:file_log_rotations ) ;
        (* Consumer for `[%log internal]` logging used for internal tracing *)
        Itn_logger.set_message_postprocessor
          Internal_tracing.For_itn_logger.post_process_message ;
        Logger.Consumer_registry.register ~id:Logger.Logger_id.mina
          ~processor:Internal_tracing.For_logger.processor
          ~transport:
            (Internal_tracing.For_logger.json_lines_rotate_transport
               ~directory:(conf_dir ^ "/internal-tracing")
               () ) ;
        let version_metadata =
          [ ("commit", `String Mina_version.commit_id)
          ; ("branch", `String Mina_version.branch)
          ; ("commit_date", `String Mina_version.commit_date)
          ; ("marlin_commit", `String Mina_version.marlin_commit_id)
          ]
        in
        [%log info]
          "Mina daemon is booting up; built with commit $commit on branch \
           $branch"
          ~metadata:version_metadata ;
        let%bind () =
          Mina_lib.Conf_dir.check_and_set_lockfile ~logger conf_dir
        in
        if not @@ String.equal daemon_expiry "never" then (
          [%log info] "Daemon will expire at $exp"
            ~metadata:[ ("exp", `String daemon_expiry) ] ;
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
        let wallets_disk_location = conf_dir ^/ "wallets" in
        let%bind wallets =
          (* Load wallets early, to give user errors before expensive
             initialization starts.
          *)
          Secrets.Wallets.load ~logger ~disk_location:wallets_disk_location
        in
        let%bind libp2p_keypair =
          let libp2p_keypair_old_format =
            match Mina_net2.Keypair.of_string libp2p_keypair with
            | Ok kp ->
                Some kp
            | Error _ ->
                if String.contains libp2p_keypair ',' then
                  [%log warn]
                    "I think -libp2p-keypair is in the old format, but I \
                     failed to parse it! Using it as a path..." ;
                None
          in
          Option.value_map
            ~default:(fun () ->
              Secrets.Libp2p_keypair.Terminal_stdin.read_exn
                ~should_prompt_user:false ~which:"libp2p keypair" libp2p_keypair
              )
            ~f:(Fn.compose const Deferred.return)
            libp2p_keypair_old_format ()
        in
        let%bind () =
          let version_filename = conf_dir ^/ "mina.version" in
          let make_version () =
            let%map () =
              (*Delete any trace files if version changes. TODO: Implement rotate logic similar to log files*)
              File_system.remove_dir (conf_dir ^/ "trace")
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
        Memory_stats.log_memory_stats logger ~process:"daemon" ;
        Parallel.init_master () ;
        let monitor = Async.Monitor.create ~name:"coda" () in
        let time_controller =
          Block_time.Controller.create @@ Block_time.Controller.basic ~logger
        in
        let pids = Child_processes.Termination.create_pid_table () in
        let mina_initialization_deferred () =
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
          let config_file_configdir =
            (conf_dir ^/ "daemon.json", `May_be_missing)
          in
          let config_file_envvar =
            match Sys.getenv "MINA_CONFIG_FILE" with
            | Some config_file ->
                Some (config_file, `Must_exist)
            | None ->
                None
          in
          let config_files =
            Option.to_list config_file_installed
            @ (config_file_configdir :: Option.to_list config_file_envvar)
            @ List.map config_files ~f:(fun config_file ->
                  (config_file, `Must_exist) )
          in
          let%bind config_jsons =
            let config_files_paths =
              List.map config_files ~f:(fun (config_file, _) ->
                  `String config_file )
            in
            [%log info] "Reading configuration files $config_files"
              ~metadata:[ ("config_files", `List config_files_paths) ] ;
            Deferred.List.filter_map config_files
              ~f:(fun (config_file, handle_missing) ->
                match%bind
                  Genesis_ledger_helper.load_config_json config_file
                with
                | Ok config_json ->
                    let%map config_json =
                      Genesis_ledger_helper.upgrade_old_config ~logger
                        config_file config_json
                    in
                    Some (config_file, config_json)
                | Error err -> (
                    match handle_missing with
                    | `Must_exist ->
                        Mina_user_error.raisef
                          ~where:"reading configuration file"
                          "The configuration file %s could not be read:\n%s"
                          config_file (Error.to_string_hum err)
                    | `May_be_missing ->
                        [%log warn]
                          "Could not read configuration from $config_file"
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
          let genesis_dir =
            Option.value ~default:(conf_dir ^/ "genesis") genesis_dir
          in
          let%bind precomputed_values =
            match%map
              Genesis_ledger_helper.init_from_config_file ~genesis_dir ~logger
                ~proof_level config
            with
            | Ok (precomputed_values, _) ->
                precomputed_values
            | Error err ->
                [%log fatal]
                  "Failed initializing with configuration $config: $error"
                  ~metadata:
                    [ ("config", Runtime_config.to_yojson config)
                    ; ("error", Error_json.error_to_yojson err)
                    ] ;
                Error.raise err
          in
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
              ~default:Currency.Fee.default_snark_worker_fee snark_work_fee
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
                           Mina_user_error.raisef
                             ~where:"decompressing a public key"
                             "The %s public key %s could not be decompressed."
                             which pk_str
                       | Some _ ->
                           Some key )
                   | Error _e ->
                       Mina_user_error.raisef ~where:"decoding a public key"
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
            match (block_production_key, block_production_pubkey) with
            | Some _, Some _ ->
                Mina_user_error.raise
                  "You cannot provide both `block-producer-key` and \
                   `block_production_pubkey`"
            | None, None ->
                Deferred.return None
            | Some sk_file, _ ->
                let%map kp =
                  Secrets.Keypair.Terminal_stdin.read_exn
                    ~should_prompt_user:false ~which:"block producer keypair"
                    sk_file
                in
                Some kp
            | _, Some tracked_pubkey ->
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
                    failwith "Expeted a sexp list" )
          in
          Stream.iter
            (Async_kernel.Async_kernel_scheduler.long_cycles_with_context
               ~at_least:(sec 0.5 |> Time_ns.Span.of_span_float_round_nearest) )
            ~f:(fun (span, context) ->
              let secs = Time_ns.Span.to_sec span in
              let monitor_infos = get_monitor_infos context.monitor in
              [%log debug]
                ~metadata:
                  [ ("long_async_cycle", `Float secs)
                  ; ("monitors", `List monitor_infos)
                  ]
                "Long async cycle, $long_async_cycle seconds, $monitors" ;
              Mina_metrics.(
                Runtime.Long_async_histogram.observe Runtime.long_async_cycle
                  secs) ) ;
          Stream.iter Async_kernel.Async_kernel_scheduler.long_jobs_with_context
            ~f:(fun (context, span) ->
              let secs = Time_ns.Span.to_sec span in
              let monitor_infos = get_monitor_infos context.monitor in
              [%log debug]
                ~metadata:
                  [ ("long_async_job", `Float secs)
                  ; ("monitors", `List monitor_infos)
                  ; ( "most_recent_2_backtrace"
                    , `String
                        (String.concat ~sep:"␤"
                           (List.map ~f:Backtrace.to_string
                              (List.take
                                 (Execution_context.backtrace_history context)
                                 2 ) ) ) )
                  ]
                "Long async job, $long_async_job seconds" ;
              Mina_metrics.(
                Runtime.Long_job_histogram.observe Runtime.long_async_job secs) ) ;
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
            (Precomputed_values.genesis_state_hashes precomputed_values)
              .state_hash
          in
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
          let epoch_ledger_location = conf_dir ^/ "epoch_ledger" in
          let module Context = struct
            let logger = logger

            let precomputed_values = precomputed_values

            let constraint_constants = precomputed_values.constraint_constants

            let consensus_constants = precomputed_values.consensus_constants
          end in
          let consensus_local_state =
            Consensus.Data.Local_state.create
              ~context:(module Context)
              ~genesis_ledger:
                (Precomputed_values.genesis_ledger precomputed_values)
              ~genesis_epoch_data:precomputed_values.genesis_epoch_data
              ~epoch_ledger_location
              ( Option.map block_production_keypair ~f:(fun keypair ->
                    let open Keypair in
                    Public_key.compress keypair.public_key )
              |> Option.to_list |> Public_key.Compressed.Set.of_list )
              ~genesis_state_hash:
                precomputed_values.protocol_state_with_hashes.hash.state_hash
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
                    Mina_user_error.raisef
                      ~where:"reading libp2p peer address file"
                      "The file %s could not be read.\n\n\
                       It must be a newline-separated list of libp2p \
                       multiaddrs (ex: /ip4/IPADDR/tcp/PORT/p2p/PEERID)"
                      file )
          in
          List.iter libp2p_peers_raw ~f:(fun raw_peer ->
              if not Mina_net2.Multiaddr.(valid_as_peer @@ of_string raw_peer)
              then
                Mina_user_error.raisef ~where:"decoding peer as a multiaddress"
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
          if enable_tracing then Mina_tracing.start conf_dir |> don't_wait_for ;
          let%bind () =
            if enable_internal_tracing then
              Internal_tracing.toggle ~logger `Enabled
            else Deferred.unit
          in
          let seed_peer_list_url =
            Option.value_map seed_peer_list_url ~f:Option.some
              ~default:
                (Option.bind config.daemon
                   ~f:(fun { Runtime_config.Daemon.peer_list_url; _ } ->
                     peer_list_url ) )
          in
          if is_seed then [%log info] "Starting node as a seed node"
          else if demo_mode then [%log info] "Starting node in demo mode"
          else if
            List.is_empty initial_peers && Option.is_none seed_peer_list_url
          then
            Mina_user_error.raise
              {|No peers were given.

Pass one of -peer, -peer-list-file, -seed, -peer-list-url.|} ;
          let chain_id =
            let protocol_major_version =
              Protocol_version.of_string_exn
                compile_time_current_protocol_version
              |> Protocol_version.major
            in
            chain_id ~genesis_state_hash
              ~genesis_constants:precomputed_values.genesis_constants
              ~constraint_system_digests:
                (Lazy.force precomputed_values.constraint_system_digests)
              ~protocol_major_version
          in
          [%log info] "Daemon will use chain id %s" chain_id ;
          let gossip_net_params =
            Gossip_net.Libp2p.Config.
              { timeout = Time.Span.of_sec 3.
              ; logger
              ; conf_dir
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
            { Mina_networking.Config.logger
            ; trust_system
            ; time_controller
            ; consensus_constants = precomputed_values.consensus_constants
            ; consensus_local_state
            ; genesis_ledger_hash
            ; constraint_constants = precomputed_values.constraint_constants
            ; log_gossip_heard
            ; is_seed
            ; creatable_gossip_net =
                Mina_networking.Gossip_net.(
                  Any.Creatable
                    ((module Libp2p), Libp2p.create ~pids gossip_net_params))
            ; precomputed_values
            }
          in
          let coinbase_receiver : Consensus.Coinbase_receiver.t =
            Option.value_map coinbase_receiver_flag ~default:`Producer
              ~f:(fun pk -> `Other pk)
          in
          let current_protocol_version =
            Mina_run.get_current_protocol_version
              ~compile_time_current_protocol_version ~conf_dir ~logger
              curr_protocol_version
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
              Mina_user_error.raise
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
                    Mina_user_error.raisef
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
          if Mina_compile_config.itn_features then
            (* set queue bound directly in Itn_logger
               adding bound to Mina_lib config introduces cycle
            *)
            Option.iter itn_max_logs ~f:Itn_logger.set_queue_bound ;
          let start_time = Time.now () in
          let%map mina =
            Mina_lib.create ~wallets
              (Mina_lib.Config.make ~logger ~pids ~trust_system ~conf_dir
                 ~chain_id ~is_seed ~super_catchup:(not no_super_catchup)
                 ~disable_node_status ~demo_mode ~coinbase_receiver ~net_config
                 ~gossip_net_params
                 ~initial_protocol_version:current_protocol_version
                 ~proposed_protocol_version_opt
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
                 ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                 ~wallets_disk_location:(conf_dir ^/ "wallets")
                 ~persistent_root_location:(conf_dir ^/ "root")
                 ~persistent_frontier_location:(conf_dir ^/ "frontier")
                 ~epoch_ledger_location ~snark_work_fee:snark_work_fee_flag
                 ~time_controller ~block_production_keypairs ~monitor
                 ~consensus_local_state ~is_archive_rocksdb
                 ~work_reassignment_wait ~archive_process_location
                 ~log_block_creation ~precomputed_values ~start_time
                 ?precomputed_blocks_path ~log_precomputed_blocks
                 ~upload_blocks_to_gcloud ~block_reward_threshold ~uptime_url
                 ~uptime_submitter_keypair ~stop_time ~node_status_url
                 ~graphql_control_port:itn_graphql_port () )
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
        let () = Mina_plugins.init_plugins ~logger mina plugins in
        return mina )

let daemon logger =
  Command.async ~summary:"Mina daemon"
    (Command.Param.map (setup_daemon logger) ~f:(fun setup_daemon () ->
         (* Immediately disable updating the time offset. *)
         Block_time.Controller.disable_setting_offset () ;
         let%bind coda = setup_daemon () in
         let%bind () = Mina_lib.start coda in
         [%log info] "Daemon ready. Clients can now connect" ;
         Async.never () ) )

let replay_blocks logger =
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
  Command.async ~summary:"Start mina daemon with blocks replayed from a file"
    (Command.Param.map3 replay_flag read_kind (setup_daemon logger)
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
         let%bind coda = setup_daemon () in
         let%bind () = Mina_lib.start_with_precomputed_blocks coda blocks in
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

[%%if force_updates]

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
    Monitor.try_with_or_error ~here:[%here] (fun () ->
        Client.get (Uri.of_string "http://updates.o1test.net/testnet_id") )
  with
  | Error e ->
      [%log error]
        "Exception while trying to fetch testnet_id: $error. Trying again in \
         $retry_minutes minutes"
        ~metadata:
          [ ("error", Error_json.error_to_yojson e)
          ; ("retry_minutes", `Int soon_minutes)
          ] ;
      try_later recheck_soon ;
      Deferred.unit
  | Ok (resp, body) -> (
      if resp.status <> `OK then (
        [%log error]
          "HTTP response status $HTTP_status while getting testnet id, \
           checking again in $retry_minutes minutes."
          ~metadata:
            [ ("HTTP_status", `String (Cohttp.Code.string_of_status resp.status))
            ; ("retry_minutes", `Int soon_minutes)
            ] ;
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
            "The version for the testnet has changed, and this client (version \
             %s) is no longer compatible. Please download the latest Mina \
             software!\n\
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
        let hashes =
          match Precomputed_values.compiled with
          | Some compiled ->
              (Lazy.force compiled).constraint_system_digests |> Lazy.force
              |> List.map ~f:(fun (_constraint_system_id, digest) ->
                     (* Throw away the constraint system ID to avoid changing the
                        format of the output here.
                     *)
                     Md5.to_hex digest )
          | None ->
              []
        in
        if json then print (Yojson.Safe.to_string (Hashes.to_yojson hashes))
        else List.iter hashes ~f:print]

let internal_commands logger =
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
                 let%bind conf_dir = Unix.mkdtemp "/tmp/mina-prover" in
                 [%log info] "Prover state being logged to %s" conf_dir ;
                 let%bind prover =
                   Prover.create ~logger
                     ~proof_level:Genesis_constants.Proof_level.compiled
                     ~constraint_constants:
                       Genesis_constants.Constraint_constants.compiled
                     ~pids:(Pid.Table.create ()) ~conf_dir ()
                 in
                 Prover.prove_from_input_sexp prover sexp >>| ignore
             | `Eof ->
                 failwith "early EOF while reading sexp" ) ) )
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
        in
        fun () ->
          let open Async in
          let logger = Logger.create () in
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
                      (List.t_of_sexp
                         (Tuple2.t_of_sexp Ledger_proof.t_of_sexp
                            Sok_message.t_of_sexp )
                         input_sexp )
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
                      [%derive.of_yojson: (Ledger_proof.t * Sok_message.t) list]
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
            Verifier.create ~logger
              ~proof_level:Genesis_constants.Proof_level.compiled
              ~constraint_constants:
                Genesis_constants.Constraint_constants.compiled
              ~pids:(Pid.Table.create ()) ~conf_dir:(Some conf_dir) ()
          in
          let%bind result =
            match input with
            | `Transaction input ->
                Verifier.verify_transaction_snarks verifier input
            | `Blockchain input ->
                Verifier.verify_blockchain_snarks verifier input
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
  ; ("replay-blocks", replay_blocks logger)
  ]

let mina_commands logger =
  [ ("accounts", Client.accounts)
  ; ("daemon", daemon logger)
  ; ("client", Client.client)
  ; ("advanced", Client.advanced)
  ; ("ledger", Client.ledger)
  ; ("libp2p", Client.libp2p)
  ; ( "internal"
    , Command.group ~summary:"Internal commands" (internal_commands logger) )
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

let print_version_info () =
  Core.printf "Commit %s on branch %s\n" Mina_version.commit_id
    Mina_version.branch

let () =
  Random.self_init () ;
  let logger = Logger.create () in
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
            (mina_commands logger) ) ) ;
  Core.exit 0

let linkme = ()
