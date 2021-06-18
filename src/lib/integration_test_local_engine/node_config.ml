open Base

module Envs = struct
  let base_node_envs =
    [ ("DAEMON_REST_PORT", "3085")
    ; ("DAEMON_CLIENT_PORT", "8301")
    ; ("DAEMON_METRICS_PORT", "10001")
    ; ("CODA_PRIVKEY_PASS", "naughty blue worm")
    ; ("CODA_LIBP2P_PASS", "")
    ]

  let snark_coord_envs ~snark_coordinator_key ~snark_worker_fee =
    [ ("CODA_SNARK_KEY", snark_coordinator_key)
    ; ("CODA_SNARK_FEE", snark_worker_fee)
    ; ("WORK_SELECTION", "seq")
    ]
    @ base_node_envs
end

module Cli_args = struct
  module Log_level = struct
    type t = Debug

    let to_string t = match t with Debug -> "Debug"
  end

  module Peer = struct
    type t = string

    let default =
      "/dns4/seed/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"
  end

  module Proof_level = struct
    type t = Full

    let to_string t = match t with Full -> "Full"
  end
end

module Cmd = struct
  open Cli_args

  module Base_command = struct
    type t =
      { peer : Peer.t
      ; log_level : Log_level.t
      ; log_snark_work_gossip : bool
      ; log_txn_pool_gossip : bool
      ; generate_genesis_proof : bool
      ; client_port : string
      ; rest_port : string
      ; metrics_port : string
      ; config_file : string
      }

    let default ~config_file =
      { peer = Peer.default
      ; log_level = Log_level.Debug
      ; log_snark_work_gossip = true
      ; log_txn_pool_gossip = true
      ; generate_genesis_proof = true
      ; client_port = "8301"
      ; rest_port = "3085"
      ; metrics_port = "10001"
      ; config_file
      }

    let to_string t =
      [ "-config-file"
      ; t.config_file
      ; "-log-level"
      ; Log_level.to_string t.log_level
      ; "-log-snark-work-gossip"
      ; Bool.to_string t.log_snark_work_gossip
      ; "-log-txn-pool-gossip"
      ; Bool.to_string t.log_txn_pool_gossip
      ; "-generate-genesis-proof"
      ; Bool.to_string t.generate_genesis_proof
      ; "-client-port"
      ; t.client_port
      ; "-rest-port"
      ; t.rest_port
      ; "-metrics-port"
      ; t.metrics_port
      ; "-peer"
      ; Peer.default
      ; "-log-json"
      ]

    let default_cmd ~config_file = default ~config_file |> to_string
  end

  module Seed_command = struct
    let cmd ~config_file =
      [ "daemon"; "-seed" ] @ Base_command.default_cmd ~config_file
  end

  module Block_producer_command = struct
    type t =
      { block_producer_key : string
      ; enable_flooding : bool
      ; enable_peer_exchange : bool
      }

    let default ~private_key_config =
      { block_producer_key = private_key_config
      ; enable_flooding = true
      ; enable_peer_exchange = true
      }

    let cmd t ~config_file =
      [ "daemon"
      ; "-block-producer-key"
      ; t.block_producer_key
      ; "-enable-flooding"
      ; Bool.to_string t.enable_flooding
      ; "-enable-peer-exchange"
      ; Bool.to_string t.enable_peer_exchange
      ]
      @ Base_command.default_cmd ~config_file
  end

  module Snark_coordinator_command = struct
    type t =
      { snark_coordinator_key : string
      ; snark_worker_fee : string
      ; work_selection : string
      }

    let default ~snark_coordinator_key ~snark_worker_fee =
      { snark_coordinator_key; snark_worker_fee; work_selection = "seq" }

    let cmd t ~config_file =
      [ "daemon"
      ; "-run-snark-coordinator"
      ; t.snark_coordinator_key
      ; "-snark-worker-fee"
      ; t.snark_worker_fee
      ; "-work-selection"
      ; t.work_selection
      ]
      @ Base_command.default_cmd ~config_file
  end

  module Snark_worker_command = struct
    type t =
      { daemon_address : string
      ; daemon_port : string
      ; proof_level : Proof_level.t
      }

    let default ~daemon_address ~daemon_port =
      { daemon_address; daemon_port; proof_level = Proof_level.Full }

    let cmd t ~config_file =
      [ "internal"
      ; "snark-worker"
      ; "-proof-level"
      ; Proof_level.to_string t.proof_level
      ; "-daemon-address"
      ; t.daemon_address ^ ":" ^ t.daemon_port
      ]
      @ Base_command.default_cmd ~config_file
  end

  type t =
    | Seed_command
    | Block_producer_command of Block_producer_command.t
    | Snark_coordinator_command of Snark_coordinator_command.t
    | Snark_worker_command of Snark_worker_command.t

  let create_cmd t ~config_file =
    match t with
    | Seed_command ->
        Seed_command.cmd ~config_file
    | Block_producer_command args ->
        Block_producer_command.cmd args ~config_file
    | Snark_coordinator_command args ->
        Snark_coordinator_command.cmd args ~config_file
    | Snark_worker_command args ->
        Snark_worker_command.cmd args ~config_file
end
