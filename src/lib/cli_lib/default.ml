open Core_kernel

(* Default values for cli flags *)
let work_reassignment_wait = 420000

let min_connections = 20

let max_connections = 50

let validation_queue_size = 150

let conf_dir_name = ".mina-config"

(** 24*7 hours *)
let stop_time = 168

let receiver_key_warning =
  "Warning: If the key is from a zkApp account, the account's receive \
   permission must be None."

let pubsub_v1 = Gossip_net.Libp2p.RW

let pubsub_v0 = Gossip_net.Libp2p.RW

let file_log_rotations = 50

let catchup_config =
  { Mina_intf.max_download_time_per_block_sec = 30.
  ; max_download_jobs = 20
  ; max_verifier_jobs = 1
  ; max_proofs_per_batch = 1000
  ; max_retrieve_hash_chain_jobs = 5
  ; building_breadcrumb_timeout = Time.Span.of_min 2.
  ; bitwap_download_timeout = Time.Span.of_min 2.
  ; peer_download_timeout = Time.Span.of_min 2.
  ; ancestry_verification_timeout = Time.Span.of_sec 30.
  ; ancestry_download_timeout = Time.Span.of_sec 300.
  ; transaction_snark_verification_timeout = Time.Span.of_min 4.
  ; bitswap_enabled = true
  }
