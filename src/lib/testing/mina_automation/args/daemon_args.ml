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
    ]
