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
  type t =
    { mutable available_ports : int list
    ; mutable used_ports : int list
    ; min_port : int
    ; max_port : int
    }

  let create ~min_port ~max_port =
    let available_ports = List.range min_port max_port in
    { available_ports; used_ports = []; min_port; max_port }

  let allocate_port t =
    match t.available_ports with
    | [] ->
        failwith "No available ports"
    | port :: rest ->
        t.available_ports <- rest ;
        t.used_ports <- port :: t.used_ports ;
        port

  (** Allocate 4 ports for a mina node: rest, client, metrics, external *)
  let allocate_ports_for_node t =
    let rest_port = allocate_port t in
    let client_port = allocate_port t in
    let metrics_port = allocate_port t in
    let external_port = allocate_port t in
    { Node_ports.rest_port; client_port; metrics_port; external_port }

  let _release_port t port =
    t.used_ports <- List.filter t.used_ports ~f:(fun p -> p <> port) ;
    t.available_ports <- port :: t.available_ports
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
      ?(start_filtered_logs = []) =
    { runtime_config_path
    ; peer
    ; log_snark_work_gossip = true
    ; log_txn_pool_gossip = true
    ; generate_genesis_proof = true
    ; log_level = "Debug"
    ; start_filtered_logs
    }

  let to_cmd_args t ~(ports : Node_ports.t) ~libp2p_key_path =
    let base_args =
      [ "-log-level"
      ; t.log_level
      ; "-log-snark-work-gossip"
      ; Bool.to_string t.log_snark_work_gossip
      ; "-log-txn-pool-gossip"
      ; Bool.to_string t.log_txn_pool_gossip
      ; "-generate-genesis-proof"
      ; Bool.to_string t.generate_genesis_proof
      ; "-client-port"
      ; Int.to_string ports.client_port
      ; "-rest-port"
      ; Int.to_string ports.rest_port
      ; "-external-port"
      ; Int.to_string ports.external_port
      ; "-metrics-port"
      ; Int.to_string ports.metrics_port
      ; "--libp2p-keypair"
      ; libp2p_key_path
      ; "-log-json"
      ; "--insecure-rest-server"
      ; "-external-ip"
      ; "0.0.0.0"
      ]
    in
    let peer_args =
      match t.peer with Some peer -> [ "-peer"; peer ] | None -> []
    in
    let start_filtered_logs_args =
      List.concat
        (List.map t.start_filtered_logs ~f:(fun log ->
             [ "--start-filtered-logs"; log ] ) )
    in
    let runtime_config_path =
      match t.runtime_config_path with
      | Some path ->
          [ "-config-file"; path ]
      | None ->
          []
    in
    List.concat
      [ base_args; runtime_config_path; peer_args; start_filtered_logs_args ]

  (* Shared with the docker engine; see
     [Integration_test_lib.Local_engine_common.node_env_vars]. *)
  let env_vars = Integration_test_lib.Local_engine_common.node_env_vars
end
