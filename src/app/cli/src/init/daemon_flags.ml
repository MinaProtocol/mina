open Core
open Async
open Cli_lib
open Signature_lib

(** The daemon's command-line flags, as given. *)
type t =
  { conf_dir : string option
  ; block_production_key : string option
  ; block_production_pubkey : Public_key.Compressed.t option
  ; block_production_password : string option
  ; itn_keys : string option
  ; itn_max_logs : int option
  ; demo_mode : bool
  ; coinbase_receiver_flag : Public_key.Compressed.t option
  ; genesis_dir : string option
  ; run_snark_worker_flag : Public_key.Compressed.t option
  ; run_snark_coordinator_flag : Public_key.Compressed.t option
  ; snark_worker_parallelism_flag : int option
  ; work_selection_method_flag : Cli_lib.Arg_type.Work_selection_method.t option
  ; libp2p_port : int Flag.Types.with_name_and_displayed_default
  ; client_port : int Flag.Types.with_name_and_displayed_default
  ; rest_server_port : int Flag.Types.with_name_and_displayed_default
  ; limited_graphql_port : int option Flag.Types.with_name
  ; itn_graphql_port : int option
  ; open_limited_graphql_port : bool
  ; archive_process_location : Host_and_port.t Flag.Types.with_name option
  ; metrics_server_port : int option
  ; gc_stat_interval : float option
  ; libp2p_metrics_port : int option
  ; external_ip_opt : string option
  ; bind_ip_opt : string option
  ; working_dir : string option
  ; is_background : bool
  ; is_archive_rocksdb : bool
  ; log_json : bool
  ; log_level : Logger.Level.t
  ; file_log_level : Logger.Level.t
  ; file_log_rotations : int
  ; snark_work_fee : Currency.Fee.t option
  ; work_reassignment_wait : int option
  ; enable_tracing : bool
  ; enable_internal_tracing : bool
  ; insecure_rest_server : bool
  ; log_received_snark_pool_diff : bool option
  ; log_transaction_pool_diff : bool option
  ; log_block_creation : bool option
  ; libp2p_keypair : string option
  ; is_seed : bool
  ; enable_flooding : bool option
  ; peer_exchange : bool option
  ; peer_protection_ratio : float
  ; min_connections : int option
  ; max_connections : int option
  ; validation_queue_size : int option
  ; direct_peers_raw : string list
  ; isolate : bool option
  ; libp2p_peers_raw : string list
  ; libp2p_peer_list_file : string option
  ; seed_peer_list_url : string option
  ; proposed_protocol_version : string option
  ; config_files : string list
  ; disable_node_status : bool
  ; cli_proof_level : Genesis_constants.Proof_level.t option
  ; precomputed_blocks_path : string option
  ; precomputed_blocks_dir : string option
  ; log_precomputed_blocks : bool
  ; start_filtered_logs : string list
  ; block_reward_threshold : Currency.Amount.t option
  ; stop_time : int option
  ; stop_time_interval : int option
  ; upload_blocks_to_gcloud : bool
  ; all_peers_seen_metric : bool
  ; node_status_url : string option
  ; node_error_url : string option
  ; simplified_node_stats : bool
  ; contact_info : string option
  ; uptime_url_string : string option
  ; uptime_submitter_key : string option
  ; uptime_submitter_pubkey : string option
  ; uptime_send_node_commit : bool
  ; hardfork_handling : Cli_lib.Arg_type.Hardfork_handling.t
  }

let param ~itn_features ~default_snark_worker_fee =
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
  and precomputed_blocks_path =
    flag "--precomputed-blocks-file"
      ~aliases:[ "precomputed-blocks-file" ]
      (optional string)
      ~doc:
        "PATH Deprecated, use --precomputed-blocks-dir. Append every \
         precomputed block as one JSON line to this file. The file grows \
         without limit and nothing rotates it"
  and precomputed_blocks_dir =
    flag "--precomputed-blocks-dir"
      ~aliases:[ "precomputed-blocks-dir" ]
      (optional string)
      ~doc:
        "DIR Write each precomputed block to its own file in this directory, \
         named <network>-<height>-<state-hash>.json, the same name the \
         precomputed block bucket uses. The directory must exist"
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
  and stop_time_interval =
    flag "--stop-time-interval" ~aliases:[ "stop-time-interval" ] (optional int)
      ~doc:
        (sprintf
           "UPTIME An upper bound (inclusive) on the random number of hours \
            added to the stop-time. Setting it to zero disables this \
            randomness. (Default: %d)"
           Cli_lib.Default.stop_time_interval )
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
                 Mina_stdlib.Mina_user_error.raisef
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
  and hardfork_handling =
    (* The two hard fork modes are migrate-exit (the "auto" hard fork mode) and
       keep-running (the "legacy" hard fork mode). See
       https://github.com/MinaProtocol/MIPs/pull/32. This option currently only
       controls the ledger sync feature (keeping migrated versions of the root
       and epoch ledger databases alongside the stable ones). TODO: the code
       will eventually need to be updated so this option also causes the daemon
       to generate and save its own hard fork config at the [slot_chain_end] and
       then shut down. *)
    flag "--hardfork-handling" ~aliases:[ "hardfork-handling" ]
      ~doc:
        "keep-running|migrate-exit Internal flag, controlling how the daemon \
         handles an upcoming hard fork. Exposed for testing purposes. \
         Currently it only causes the daemon to maintain migrated versions of \
         the root and epoch ledger databases alongside the stable databases. \
         (default: keep-running). "
      (optional_with_default Hardfork_handling.Keep_running
         Hardfork_handling.arg )
  in
  { conf_dir
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
  }
