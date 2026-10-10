open Core_kernel

module Node_ports = struct
  type t =
    { rest_port : int
    ; client_port : int
    ; metrics_port : int
    ; external_port : int
    }
  [@@deriving to_yojson]
end

module PortManager = struct
  type t = Mina_automation_process.Ports.t

  let create = Mina_automation_process.Ports.create

  let allocate_port = Mina_automation_process.Ports.allocate

  (** Allocate 4 ports for a mina node: rest, client, metrics, external *)
  let allocate_ports_for_node t =
    let rest_port = allocate_port t in
    let client_port = allocate_port t in
    let metrics_port = allocate_port t in
    let external_port = allocate_port t in
    { Node_ports.rest_port; client_port; metrics_port; external_port }
end

module Seed_config = struct
  (* Seed identity is shared verbatim with the docker engine; see
     [Integration_test_lib.Local_engine_common.Seed]. *)
  let peer_id = Integration_test_lib.Local_engine_common.Seed.peer_id

  let libp2p_keypair =
    Integration_test_lib.Local_engine_common.Seed.libp2p_keypair

  let create_libp2p_peer ~external_port =
    Printf.sprintf "/ip4/127.0.0.1/tcp/%d/p2p/%s" external_port peer_id
end

module Base_node_config = struct
  type t =
    { peer : string option
    ; log_level : string
    ; log_snark_work_gossip : bool
    ; log_txn_pool_gossip : bool
    ; generate_genesis_proof : bool
    ; runtime_config_path : string option
    ; start_filtered_logs : string list
    }
  [@@deriving to_yojson]

  let default ?(runtime_config_path = None) ?(peer = None)
      ?(start_filtered_logs = []) () =
    { runtime_config_path
    ; peer
    ; log_snark_work_gossip = true
    ; log_txn_pool_gossip = true
    ; generate_genesis_proof = true
    ; log_level = "Debug"
    ; start_filtered_logs
    }

  let to_cmd_args t ~(ports : Node_ports.t) ~libp2p_key_path =
    Mina_automation_args.Daemon_args.to_list
      { Mina_automation_args.Daemon_args.log_level = Some t.log_level
      ; log_snark_work_gossip = Some t.log_snark_work_gossip
      ; log_txn_pool_gossip = Some t.log_txn_pool_gossip
      ; generate_genesis_proof = Some t.generate_genesis_proof
      ; client_port = Some ports.client_port
      ; rest_port = Some ports.rest_port
      ; external_port = Some ports.external_port
      ; metrics_port = Some ports.metrics_port
      ; libp2p_keypair = Some libp2p_key_path
      ; log_json = true
      ; insecure_rest_server = true
      ; external_ip = Some "0.0.0.0"
      ; config_files = Option.to_list t.runtime_config_path
      ; peers = Option.to_list t.peer
      ; start_filtered_logs = t.start_filtered_logs
      }

  let%test_unit "to_cmd_args keeps the daemon arguments" =
    let t =
      default ~runtime_config_path:(Some "/cfg.json") ~peer:(Some "/ip4/peer")
        ~start_filtered_logs:[ "evt" ] ()
    in
    let ports =
      { Node_ports.rest_port = 1
      ; client_port = 2
      ; metrics_port = 3
      ; external_port = 4
      }
    in
    let actual = to_cmd_args t ~ports ~libp2p_key_path:"/key" in
    let expected =
      [ "-log-level"
      ; "Debug"
      ; "-log-snark-work-gossip"
      ; "true"
      ; "-log-txn-pool-gossip"
      ; "true"
      ; "-generate-genesis-proof"
      ; "true"
      ; "-client-port"
      ; "2"
      ; "-rest-port"
      ; "1"
      ; "-external-port"
      ; "4"
      ; "-metrics-port"
      ; "3"
      ; "--libp2p-keypair"
      ; "/key"
      ; "-log-json"
      ; "--insecure-rest-server"
      ; "-external-ip"
      ; "0.0.0.0"
      ; "-config-file"
      ; "/cfg.json"
      ; "-peer"
      ; "/ip4/peer"
      ; "--start-filtered-logs"
      ; "evt"
      ]
    in
    if not (List.equal String.equal actual expected) then
      failwithf "unexpected daemon arguments: %s"
        (String.concat ~sep:" " actual)
        ()

  (* Shared with the docker engine; see
     [Integration_test_lib.Local_engine_common.node_env_vars]. *)
  let env_vars = Integration_test_lib.Local_engine_common.node_env_vars
end
