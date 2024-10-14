open Core
open Async
open Mina_base
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

(* keep this code in sync with Client.chain_id_inputs, Mina_commands.chain_id_inputs, and
   Daemon_rpcs.Chain_id_inputs
*)
let chain_id ~constraint_system_digests ~genesis_state_hash ~genesis_constants
    ~protocol_transaction_version ~protocol_network_version =
  (* if this changes, also change Mina_commands.chain_id_inputs *)
  let genesis_state_hash = State_hash.to_base58_check genesis_state_hash in
  let genesis_constants_hash = Genesis_constants.hash genesis_constants in
  let all_snark_keys =
    List.map constraint_system_digests ~f:(fun (_, digest) -> Md5.to_hex digest)
    |> String.concat ~sep:""
  in
  let version_digest v = Int.to_string v |> Md5.digest_string |> Md5.to_hex in
  let protocol_transaction_version_digest =
    version_digest protocol_transaction_version
  in
  let protocol_network_version_digest =
    version_digest protocol_network_version
  in
  let b2 =
    Blake2.digest_string
      ( genesis_state_hash ^ all_snark_keys ^ genesis_constants_hash
      ^ protocol_transaction_version_digest ^ protocol_network_version_digest )
  in
  Blake2.to_hex b2

let plugin_flag =
  if Node_config.plugins then
    let open Command.Param in
    flag "--load-plugin" ~aliases:[ "load-plugin" ] (listed string)
      ~doc:
        "PATH The path to load a .cmxs plugin from. May be passed multiple \
         times"
  else Command.Param.return []

let load_config_files ~logger ~genesis_constants ~constraint_constants ~conf_dir
    ~genesis_dir ~cli_proof_level ~proof_level config_files =
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
                Mina_user_error.raisef ~where:"reading configuration file"
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
  let genesis_dir = Option.value ~default:(conf_dir ^/ "genesis") genesis_dir in
  let%bind precomputed_values =
    match%map
      Genesis_ledger_helper.init_from_config_file ~cli_proof_level ~genesis_dir
        ~logger ~genesis_constants ~constraint_constants ~proof_level config
    with
    | Ok (precomputed_values, _) ->
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
  return (precomputed_values, config_jsons, config)

let setup_daemon logger ~itn_features ~default_snark_worker_fee =
  let open Command.Let_syntax in
  let open Cli_lib.Arg_type in
  let receiver_key_warning = Cli_lib.Default.receiver_key_warning in
  let%map_open conf_dir = Cli_lib.Flag.conf_dir
  and block_production_key =
    flag "--block-producer-key" ~aliases:[ "block-producer-key" ]
      ~doc:
        (sprintf
           "DEPRECATED: Use environment variable `MINA_BP_PRIVKEY` instead. \
            Private key file for the block producer. Providing this flag or \
            the environment variable will enable block production. You cannot \
            provide both `block-producer-key` and `block-producer-pubkey`. \
            (default: use environment variable `MINA_BP_PRIVKEY`, if provided, \
            or else don't produce any blocks) %s"
           receiver_key_warning )
      (optional string)
  and block_production_pubkey =
    flag "--block-producer-pubkey"
      ~aliases:[ "block-producer-pubkey" ]
      ~doc:
        (sprintf
           "PUBLICKEY Public key for the associated private key that is being \
            tracked by this daemon. You cannot provide both \
            `block-producer-key` (or `MINA_BP_PRIVKEY`) and \
            `block-producer-pubkey`. (default: don't produce blocks) %s"
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
    if itn_features then
      flag "--itn-keys" ~aliases:[ "itn-keys" ] (optional string)
        ~doc:
          "PUBLICKEYS A comma-delimited list of Ed25519 public keys that are \
           permitted to send signed requests to the incentivized testnet \
           GraphQL server"
    else Command.Param.return None
  and itn_max_logs =
    if itn_features then
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
        "seq|rand|roffset Choose work sequentially (seq), randomly (rand), or \
         sequentially with a random offset (roffset) (default: rand)"
      (optional work_selection_method)
  and libp2p_port = Flag.Port.Daemon.external_
  and client_port = Flag.Port.Daemon.client
  and rest_server_port = Flag.Port.Daemon.rest_server
  and limited_graphql_port = Flag.Port.Daemon.limited_graphql_server
  and itn_graphql_port =
    if itn_features then
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
           (Currency.Fee.to_nanomina_int default_snark_worker_fee) )
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
    flag "--libp2p-keypair" ~aliases:[ "libp2p-keypair" ] (optional string)
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
  and cli_proof_level =
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
  and start_filtered_logs =
    flag "--start-filtered-logs" (listed string)
      ~doc:
        "LOG-FILTER Include filtered logs for the given filter. May be passed \
         multiple times"
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
  and simplified_node_stats =
    flag "--simplified-node-stats"
      ~aliases:[ "simplified-node-stats" ]
      (optional_with_default true bool)
      ~doc:"whether to report simplified node stats (default: true)"
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
  and uptime_send_node_commit =
    flag "--uptime-send-node-commit-sha"
      ~aliases:[ "uptime-send-node-commit-sha" ]
      ~doc:
        "true|false Whether to send the commit SHA used to build the node to \
         the uptime service. (default: false)"
      no_arg
  in
  let to_pubsub_topic_mode_option =
    let open Gossip_net.Libp2p in
    function
    | "ro" ->
        Some RO
    | "rw" ->
        Some RW
    | "none" ->
        Some N
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
          else Option.iter working_dir ~f:Caml.Sys.chdir
        in
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
          let genesis_constants =
            Genesis_constants.Compiled.genesis_constants
          in
          let constraint_constants =
            Genesis_constants.Compiled.constraint_constants
          in
          let compile_config = Mina_compile_config.Compiled.t in
          let%bind precomputed_values, config_jsons, config =
            load_config_files ~logger ~conf_dir ~genesis_dir
              ~proof_level:Genesis_constants.Compiled.proof_level config_files
              ~genesis_constants ~constraint_constants ~cli_proof_level
          in

          constraint_constants.block_window_duration_ms |> Float.of_int
          |> Time.Span.of_ms |> Mina_metrics.initialize_all ;

          (* We reverse the list because we want to find the "most relevant" value, i.e. the
             last time it was declared in the list of supplied config files
          *)
          let rev_daemon_configs =
            List.rev_filter_map config_jsons
              ~f:(fun (config_file, config_json) ->
                Yojson.Safe.Util.member "daemon" config_json
                |> fun x ->
                Runtime_config.Daemon.of_yojson x
                |> Result.ok
                |> Option.map ~f:(fun daemon_config ->
                       (config_file, daemon_config) ) )
          in

          let module DC = Runtime_config.Daemon in
          (* The explicit typing here is necessary to prevent type inference from specializing according
             to the first usage.
          *)
          let maybe_from_config (type a) :
                 getter:(DC.t -> a option)
              -> keyname:string
              -> preferred_value:a option
              -> a option =
           fun ~getter ~keyname ~preferred_value ->
            Runtime_config.Config_loader.maybe_from_config ~logger
              ~configs:rev_daemon_configs ~getter ~keyname ~preferred_value
          in
          let or_from_config (type a) :
                 getter:(DC.t -> a option)
              -> keyname:string
              -> preferred_value:a option
              -> default:a
              -> a =
           fun ~getter ~keyname ~preferred_value ~default ->
            Runtime_config.Config_loader.or_from_config ~logger
              ~configs:rev_daemon_configs ~getter ~keyname ~preferred_value
              ~default
          in

          let libp2p_port =
            or_from_config ~keyname:"libp2p-port" ~getter:DC.libp2p_port
              ~preferred_value:libp2p_port.value ~default:libp2p_port.default
          in
          let rest_server_port =
            or_from_config ~keyname:"rest-port" ~getter:DC.rest_port
              ~preferred_value:rest_server_port.value
              ~default:rest_server_port.default
          in
          let limited_graphql_port =
            maybe_from_config ~keyname:"limited-graphql-port"
              ~getter:DC.graphql_port
              ~preferred_value:limited_graphql_port.value
          in
          let client_port =
            or_from_config ~keyname:"client-port" ~getter:DC.client_port
              ~preferred_value:client_port.value ~default:client_port.default
          in
          let snark_work_fee =
            or_from_config ~keyname:"snark-worker-fee"
              ~getter:(fun x ->
                DC.snark_worker_fee x
                |> Option.map ~f:Currency.Fee.of_nanomina_int_exn )
              ~preferred_value:snark_work_fee
              ~default:compile_config.default_snark_worker_fee
          in
          let node_status_url =
            maybe_from_config ~keyname:"node-status-url"
              ~getter:DC.node_status_url ~preferred_value:node_status_url
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
            or_from_config ~keyname:"work-selection"
              ~getter:(fun x ->
                DC.work_selection x
                |> Option.map ~f:Cli_lib.Arg_type.work_selection_method_val )
              ~preferred_value:work_selection_method_flag
              ~default:Cli_lib.Arg_type.Work_selection_method.Random
          in
          let work_reassignment_wait =
            or_from_config ~keyname:"work-reassignment-wait"
              ~getter:DC.work_reassignment_wait
              ~preferred_value:work_reassignment_wait
              ~default:Cli_lib.Default.work_reassignment_wait
          in
          let log_received_snark_pool_diff =
            or_from_config ~keyname:"log-snark-work-gossip"
              ~getter:DC.log_snark_work_gossip
              ~preferred_value:log_received_snark_pool_diff ~default:false
          in
          let log_transaction_pool_diff =
            or_from_config ~keyname:"log-txn-pool-gossip"
              ~getter:DC.log_txn_pool_gossip
              ~preferred_value:log_transaction_pool_diff ~default:false
          in
          let log_block_creation =
            or_from_config ~keyname:"log-block-creation"
              ~getter:DC.log_block_creation ~preferred_value:log_block_creation
              ~default:true
          in
          let log_gossip_heard =
            { Mina_networking.Config.snark_pool_diff =
                log_received_snark_pool_diff
            ; transaction_pool_diff = log_transaction_pool_diff
            ; new_state = true
            }
          in
          let to_publickey_compressed_option which pk_str =
            match Public_key.Compressed.of_base58_check pk_str with
            | Ok key -> (
                match Public_key.decompress key with
                | None ->
                    Mina_user_error.raisef ~where:"decompressing a public key"
                      "The %s public key %s could not be decompressed." which
                      pk_str
                | Some _ ->
                    Some key )
            | Error _e ->
                Mina_user_error.raisef ~where:"decoding a public key"
                  "The %s public key %s could not be decoded." which pk_str
          in
          let run_snark_worker_flag =
            maybe_from_config ~keyname:"run-snark-worker"
              ~getter:
                Option.(
                  fun x ->
                    DC.run_snark_worker x
                    >>= to_publickey_compressed_option "snark_worker")
              ~preferred_value:run_snark_worker_flag
          in
          let run_snark_coordinator_flag =
            maybe_from_config ~keyname:"run-snark-coordinator"
              ~getter:
                Option.(
                  fun x ->
                    DC.run_snark_coordinator x
                    >>= to_publickey_compressed_option "snark_coordinator")
              ~preferred_value:run_snark_coordinator_flag
          in
          let snark_worker_parallelism_flag =
            maybe_from_config ~keyname:"snark-worker-parallelism"
              ~getter:DC.snark_worker_parallelism
              ~preferred_value:snark_worker_parallelism_flag
          in
          let coinbase_receiver_flag =
            maybe_from_config ~keyname:"coinbase-receiver"
              ~getter:
                Option.(
                  fun x ->
                    DC.coinbase_receiver x
                    >>= to_publickey_compressed_option "coinbase_receiver")
              ~preferred_value:coinbase_receiver_flag
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
            maybe_from_config ~keyname:"block-producer-key"
              ~getter:DC.block_producer_key
              ~preferred_value:block_production_key
          in
          let block_production_pubkey =
            maybe_from_config ~keyname:"block-producer-pubkey"
              ~getter:
                Option.(
                  fun x ->
                    DC.block_producer_pubkey x
                    >>= to_publickey_compressed_option "block_producer")
              ~preferred_value:block_production_pubkey
          in
          let block_production_password =
            maybe_from_config ~keyname:"block-producer-password"
              ~getter:DC.block_producer_password
              ~preferred_value:block_production_password
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
                Mina_user_error.raise
                  "You cannot provide both `block-producer-key` and \
                   `block_production_pubkey`"
            | None, Some _, Some _ ->
                Mina_user_error.raise
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
          let trust_dir = conf_dir ^/ "trust" in
          let%bind () = Async.Unix.mkdir ~p:() trust_dir in
          let%bind trust_system = Trust_system.create trust_dir in
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
            let peers =
              or_from_config ~keyname:"peers" ~getter:DC.peers
                ~preferred_value:None ~default:[]
            in
            List.concat
              [ List.map ~f:Mina_net2.Multiaddr.of_string libp2p_peers_raw
              ; peer_list_file_contents_or_empty
              ; List.map ~f:Mina_net2.Multiaddr.of_string @@ peers
              ]
          in
          let direct_peers =
            List.map ~f:Mina_net2.Multiaddr.of_string direct_peers_raw
          in
          let min_connections =
            or_from_config ~keyname:"min-connections" ~getter:DC.min_connections
              ~preferred_value:min_connections
              ~default:Cli_lib.Default.min_connections
          in
          let max_connections =
            or_from_config ~keyname:"max-connections" ~getter:DC.max_connections
              ~preferred_value:max_connections
              ~default:Cli_lib.Default.max_connections
          in
          let pubsub_v1 = Gossip_net.Libp2p.N in
          (* TODO uncomment after introducing Bitswap-based block retrieval *)
          (* let pubsub_v1 =
               or_from_config to_pubsub_topic_mode_option "pubsub-v1"
                 ~default:Cli_lib.Default.pubsub_v1 pubsub_v1
             in *)
          let pubsub_v0 =
            or_from_config ~keyname:"pubsub-v0"
              ~getter:
                Option.(fun x -> DC.pubsub_v0 x >>= to_pubsub_topic_mode_option)
              ~preferred_value:None ~default:Cli_lib.Default.pubsub_v0
          in

          let validation_queue_size =
            or_from_config ~keyname:"validation-queue-size"
              ~getter:DC.validation_queue_size
              ~preferred_value:validation_queue_size
              ~default:Cli_lib.Default.validation_queue_size
          in
          let stop_time =
            or_from_config ~keyname:"stop-time" ~getter:DC.stop_time
              ~preferred_value:stop_time ~default:Cli_lib.Default.stop_time
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
          if is_seed then [%log info] "Starting node as a seed node"
          else if demo_mode then [%log info] "Starting node in demo mode"
          else if
            List.is_empty initial_peers && Option.is_none seed_peer_list_url
          then
            Mina_user_error.raise
              {|No peers were given.

Pass one of -peer, -peer-list-file, -seed, -peer-list-url.|} ;
          let chain_id =
            let protocol_transaction_version =
              Protocol_version.(transaction current)
            in
            let protocol_network_version =
              Protocol_version.(transaction current)
            in
            chain_id ~genesis_state_hash
              ~genesis_constants:precomputed_values.genesis_constants
              ~constraint_system_digests:
                (Lazy.force precomputed_values.constraint_system_digests)
              ~protocol_transaction_version ~protocol_network_version
          in
          [%log info] "Daemon will use chain id %s" chain_id ;
          [%log info] "Daemon running protocol version %s"
            Protocol_version.(to_string current) ;
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
              ; block_window_duration = compile_config.block_window_duration
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
          if compile_config.itn_features then
            (* set queue bound directly in Itn_logger
               adding bound to Mina_lib config introduces cycle
            *)
            Option.iter itn_max_logs ~f:Itn_logger.set_queue_bound ;
          let start_time = Time.now () in
          let%map mina =
            Mina_lib.create ~commit_id:Mina_version.commit_id ~wallets
              (Mina_lib.Config.make ~logger ~pids ~trust_system ~conf_dir
                 ~chain_id ~is_seed ~super_catchup:(not no_super_catchup)
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
                 ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                 ~wallets_disk_location:(conf_dir ^/ "wallets")
                 ~persistent_root_location:(conf_dir ^/ "root")
                 ~persistent_frontier_location:(conf_dir ^/ "frontier")
                 ~epoch_ledger_location ~snark_work_fee ~time_controller
                 ~block_production_keypairs ~monitor ~consensus_local_state
                 ~is_archive_rocksdb ~work_reassignment_wait
                 ~archive_process_location ~log_block_creation
                 ~precomputed_values ~start_time ?precomputed_blocks_path
                 ~log_precomputed_blocks ~start_filtered_logs
                 ~upload_blocks_to_gcloud ~block_reward_threshold ~uptime_url
                 ~uptime_submitter_keypair ~uptime_send_node_commit ~stop_time
                 ~node_status_url ~graphql_control_port:itn_graphql_port
                 ~simplified_node_stats
                 ~zkapp_cmd_limit:(ref compile_config.zkapp_cmd_limit)
                 ~compile_config () )
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
  let compile_config = Mina_compile_config.Compiled.t in
  Command.async ~summary:"Mina daemon"
    (Command.Param.map
       (setup_daemon logger ~itn_features:compile_config.itn_features
          ~default_snark_worker_fee:compile_config.default_snark_worker_fee )
       ~f:(fun setup_daemon () ->
         (* Immediately disable updating the time offset. *)
         Block_time.Controller.disable_setting_offset () ;
         let%bind mina = setup_daemon () in
         let%bind () = Mina_lib.start mina in
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
  let compile_config = Mina_compile_config.Compiled.t in
  Command.async ~summary:"Start mina daemon with blocks replayed from a file"
    (Command.Param.map3 replay_flag read_kind
       (setup_daemon logger ~itn_features:compile_config.itn_features
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
  | "Bounded_types.String.t"
  | "Bounded_types.String.Tagged.t"
  | "Bounded_types.Array.t" ->
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

let internal_commands logger =
  [ ( Snark_worker.Intf.command_name
    , Snark_worker.command ~proof_level:Genesis_constants.Compiled.proof_level
        ~constraint_constants:Genesis_constants.Compiled.constraint_constants
        ~commit_id:Mina_version.commit_id )
  ; ("snark-hashes", snark_hashes)
  ; ( "run-prover"
    , Command.async
        ~summary:"Run prover on a sexp provided on a single line of stdin"
        (Command.Param.return (fun () ->
             let logger = Logger.create () in
             let constraint_constants =
               Genesis_constants.Compiled.constraint_constants
             in
             let proof_level = Genesis_constants.Compiled.proof_level in
             Parallel.init_master () ;
             match%bind Reader.read_sexp (Lazy.force Reader.stdin) with
             | `Ok sexp ->
                 let%bind conf_dir = Unix.mkdtemp "/tmp/mina-prover" in
                 [%log info] "Prover state being logged to %s" conf_dir ;
                 let%bind prover =
                   Prover.create ~commit_id:Mina_version.commit_id ~logger
                     ~proof_level ~constraint_constants
                     ~pids:(Pid.Table.create ()) ~conf_dir ()
                 in
                 Prover.prove_from_input_sexp prover sexp >>| ignore
             | `Eof ->
                 failwith "early EOF while reading sexp" ) ) )
  ; ( "run-snark-worker-single"
    , Command.async
        ~summary:"Run snark-worker on a sexp provided on a single line of stdin"
        (let open Command.Let_syntax in
        let%map_open filename =
          flag "--file" (required string)
            ~doc:"File containing the s-expression of the snark work to execute"
        in
        fun () ->
          let open Deferred.Let_syntax in
          let logger = Logger.create () in
          let constraint_constants =
            Genesis_constants.Compiled.constraint_constants
          in
          let proof_level = Genesis_constants.Compiled.proof_level in
          Parallel.init_master () ;
          match%bind
            Reader.with_file filename ~f:(fun reader ->
                [%log info] "Created reader for %s" filename ;
                Reader.read_sexp reader )
          with
          | `Ok sexp -> (
              let%bind worker_state =
                Snark_worker.Prod.Inputs.Worker_state.create ~proof_level
                  ~constraint_constants ()
              in
              let sok_message =
                { Mina_base.Sok_message.fee = Currency.Fee.of_mina_int_exn 0
                ; prover = Quickcheck.random_value Public_key.Compressed.gen
                }
              in
              let spec =
                [%of_sexp:
                  ( Transaction_witness.t
                  , Ledger_proof.t )
                  Snark_work_lib.Work.Single.Spec.t] sexp
              in
              match%map
                Snark_worker.Prod.Inputs.perform_single worker_state
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
          let constraint_constants =
            Genesis_constants.Compiled.constraint_constants
          in
          let proof_level = Genesis_constants.Compiled.proof_level in
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
            Verifier.create ~commit_id:Mina_version.commit_id ~logger
              ~proof_level ~constraint_constants ~pids:(Pid.Table.create ())
              ~conf_dir:(Some conf_dir) ()
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
  ; ("replay-blocks", replay_blocks logger)
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
        in
        fun () ->
          let open Deferred.Let_syntax in
          Parallel.init_master () ;
          let logger = Logger.create () in
          let conf_dir = Mina_lib.Conf_dir.compute_conf_dir conf_dir in
          let genesis_constants =
            Genesis_constants.Compiled.genesis_constants
          in
          let constraint_constants =
            Genesis_constants.Compiled.constraint_constants
          in
          let proof_level = Genesis_constants.Proof_level.Full in
          let config_files =
            List.map config_files ~f:(fun config_file ->
                (config_file, `Must_exist) )
          in
          let%bind precomputed_values, _config_jsons, _config =
            load_config_files ~logger ~conf_dir ~genesis_dir ~genesis_constants
              ~constraint_constants ~proof_level config_files
              ~cli_proof_level:None
          in
          let pids = Child_processes.Termination.create_pid_table () in
          let%bind prover =
            (* We create a prover process (unnecessarily) here, to have a more
               realistic test.
            *)
            Prover.create ~commit_id:Mina_version.commit_id ~logger ~pids
              ~conf_dir ~proof_level
              ~constraint_constants:precomputed_values.constraint_constants ()
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
  ]

let mina_commands logger ~itn_features =
  [ ("accounts", Client.accounts)
  ; ("daemon", daemon logger)
  ; ("client", Client.client)
  ; ("advanced", Client.advanced ~itn_features)
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

let print_version_info () = Core.printf "Commit %s\n" Mina_version.commit_id

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
       let compile_config = Mina_compile_config.Compiled.t in
       Command.run
         (Command.group ~summary:"Mina" ~preserve_subcommand_order:()
            (mina_commands logger ~itn_features:compile_config.itn_features) )
  ) ;
  Core.exit 0

let linkme = ()
