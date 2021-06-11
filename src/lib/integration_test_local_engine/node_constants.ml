let default_seed_envs =
  [ ("DAEMON_REST_PORT", "3085")
  ; ("DAEMON_CLIENT_PORT", "8301")
  ; ("DAEMON_METRICS_PORT", "10001")
  ; ("CODA_LIBP2P_PASS", "") ]

let default_block_producer_envs =
  [ ("DAEMON_REST_PORT", "3085")
  ; ("DAEMON_CLIENT_PORT", "8301")
  ; ("DAEMON_METRICS_PORT", "10001")
  ; ("CODA_PRIVKEY_PASS", "naughty blue worm")
  ; ("CODA_LIBP2P_PASS", "") ]

let default_snark_coord_envs ~snark_coordinator_key ~snark_worker_fee =
  [ ("DAEMON_REST_PORT", "3085")
  ; ("DAEMON_CLIENT_PORT", "8301")
  ; ("DAEMON_METRICS_PORT", "10001")
  ; ("CODA_SNARK_KEY", snark_coordinator_key)
  ; ("CODA_SNARK_FEE", snark_worker_fee)
  ; ("WORK_SELECTION", "seq")
  ; ("CODA_PRIVKEY_PASS", "naughty blue worm")
  ; ("CODA_LIBP2P_PASS", "") ]

let default_seed_command ~runtime_config =
  [ "daemon"
  ; "-log-level"
  ; "Debug"
  ; "-log-json"
  ; "-log-snark-work-gossip"
  ; "true"
  ; "-client-port"
  ; "8301"
  ; "-generate-genesis-proof"
  ; "true"
  ; "-peer"
  ; "/dns4/seed/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
  ; "-seed"
  ; "-config-file"
  ; runtime_config ]

let default_block_producer_command ~runtime_config ~private_key_config =
  [ "daemon"
  ; "-log-level"
  ; "Debug"
  ; "-log-json"
  ; "-log-snark-work-gossip"
  ; "true"
  ; "-log-txn-pool-gossip"
  ; "true"
  ; "-enable-peer-exchange"
  ; "true"
  ; "-enable-flooding"
  ; "true"
  ; "-peer"
  ; "/dns4/seed/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
  ; "-client-port"
  ; "8301"
  ; "-generate-genesis-proof"
  ; "true"
  ; "-block-producer-key"
  ; private_key_config
  ; "-config-file"
  ; runtime_config ]

let default_snark_coord_command ~runtime_config ~snark_coordinator_key
    ~snark_worker_fee =
  [ "daemon"
  ; "-log-level"
  ; "Debug"
  ; "-log-json"
  ; "-log-snark-work-gossip"
  ; "true"
  ; "-log-txn-pool-gossip"
  ; "true"
  ; "-external-port"
  ; "10909"
  ; "-rest-port"
  ; "3085"
  ; "-client-port"
  ; "8301"
  ; "-work-selection"
  ; "seq"
  ; "-peer"
  ; "/dns4/seed/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
  ; "-run-snark-coordinator"
  ; snark_coordinator_key
  ; "-snark-worker-fee"
  ; snark_worker_fee
  ; "-config-file"
  ; runtime_config ]

let default_snark_worker_command ~daemon_address =
  [ "internal"
  ; "snark-worker"
  ; "-proof-level"
  ; "full"
  ; "-daemon-address"
  ; daemon_address ^ ":8301" ]
