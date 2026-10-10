(** Command-line arguments of [mina daemon], as data. Every test engine and
    driver that starts a daemon builds its arguments here. *)

open Core_kernel

type t =
  { log_level : string option
  ; log_json : bool
  ; log_snark_work_gossip : bool option
  ; log_txn_pool_gossip : bool option
  ; generate_genesis_proof : bool option
  ; client_port : int option
  ; rest_port : int option
  ; external_port : int option
  ; metrics_port : int option
  ; libp2p_keypair : string option
  ; insecure_rest_server : bool
  ; external_ip : string option
  ; config_files : string list
  ; peers : string list
  ; start_filtered_logs : string list
  ; seed : bool
  ; demo_mode : bool
  ; working_dir : string option
  ; config_directory : string option
  ; genesis_ledger_dir : string option
  ; hardfork_handling : string option
  ; block_producer_key : string option
  ; node_status_url : string option
  ; node_error_url : string option
  ; simplified_node_stats : bool option
  ; peer_list_url : string option
  }

let default =
  { log_level = None
  ; log_json = false
  ; log_snark_work_gossip = None
  ; log_txn_pool_gossip = None
  ; generate_genesis_proof = None
  ; client_port = None
  ; rest_port = None
  ; external_port = None
  ; metrics_port = None
  ; libp2p_keypair = None
  ; insecure_rest_server = false
  ; external_ip = None
  ; config_files = []
  ; peers = []
  ; start_filtered_logs = []
  ; seed = false
  ; demo_mode = false
  ; working_dir = None
  ; config_directory = None
  ; genesis_ledger_dir = None
  ; hardfork_handling = None
  ; block_producer_key = None
  ; node_status_url = None
  ; node_error_url = None
  ; simplified_node_stats = None
  ; peer_list_url = None
  }

let to_list t =
  let opt flag f = function None -> [] | Some v -> [ flag; f v ] in
  let flag name enabled = if enabled then [ name ] else [] in
  let each flag values = List.concat_map values ~f:(fun v -> [ flag; v ]) in
  List.concat
    [ opt "-log-level" Fn.id t.log_level
    ; opt "-log-snark-work-gossip" Bool.to_string t.log_snark_work_gossip
    ; opt "-log-txn-pool-gossip" Bool.to_string t.log_txn_pool_gossip
    ; opt "-generate-genesis-proof" Bool.to_string t.generate_genesis_proof
    ; opt "-client-port" Int.to_string t.client_port
    ; opt "-rest-port" Int.to_string t.rest_port
    ; opt "-external-port" Int.to_string t.external_port
    ; opt "-metrics-port" Int.to_string t.metrics_port
    ; opt "--libp2p-keypair" Fn.id t.libp2p_keypair
    ; flag "-log-json" t.log_json
    ; flag "--insecure-rest-server" t.insecure_rest_server
    ; opt "-external-ip" Fn.id t.external_ip
    ; each "-config-file" t.config_files
    ; each "-peer" t.peers
    ; each "--start-filtered-logs" t.start_filtered_logs
    ; flag "--seed" t.seed
    ; flag "--demo-mode" t.demo_mode
    ; opt "--working-dir" Fn.id t.working_dir
    ; opt "--config-directory" Fn.id t.config_directory
    ; opt "--genesis-ledger-dir" Fn.id t.genesis_ledger_dir
    ; opt "--hardfork-handling" Fn.id t.hardfork_handling
    ; opt "--block-producer-key" Fn.id t.block_producer_key
    ; opt "--node-status-url" Fn.id t.node_status_url
    ; opt "--node-error-url" Fn.id t.node_error_url
    ; opt "--simplified-node-stats" Bool.to_string t.simplified_node_stats
    ; opt "--peer-list-url" Fn.id t.peer_list_url
    ]
