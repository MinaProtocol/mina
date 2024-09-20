open Core_kernel
include Node_config_unconfigurable_constants

[%%import "/src/config.mlh"]

[%%inject "ledger_depth", ledger_depth]

[%%inject "curve_size", curve_size]

[%%inject "coinbase", coinbase]

[%%inject "k", k]

[%%inject "delta", delta]

[%%inject "slots_per_epoch", slots_per_epoch]

[%%inject "slots_per_sub_window", slots_per_sub_window]

[%%inject "sub_windows_per_window", sub_windows_per_window]

[%%inject "grace_period_slots", grace_period_slots]

[%%inject "scan_state_with_tps_goal", scan_state_with_tps_goal]

[%%ifndef scan_state_transaction_capacity_log_2]

let scan_state_transaction_capacity_log_2 : int option = None

[%%else]

[%%inject
"scan_state_transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

let scan_state_transaction_capacity_log_2 =
  Some scan_state_transaction_capacity_log_2

[%%endif]

[%%inject "scan_state_work_delay", scan_state_work_delay]

[%%inject "proof_level", proof_level]

[%%inject "pool_max_size", pool_max_size]

[%%inject "account_creation_fee_int", account_creation_fee_int]

[%%inject "default_transaction_fee", default_transaction_fee]

[%%inject "default_snark_worker_fee", default_snark_worker_fee]

[%%inject "minimum_user_command_fee", minimum_user_command_fee]

[%%inject "supercharged_coinbase_factor", supercharged_coinbase_factor]

[%%inject "genesis_state_timestamp", genesis_state_timestamp]

[%%inject "block_window_duration", block_window_duration]

[%%inject "itn_features", itn_features]

[%%ifndef compaction_interval]

let compaction_interval = None

[%%else]

[%%inject "compaction_interval", compaction_interval]

let compaction_interval = Some compaction_interval

[%%endif]

[%%inject "network", network]

[%%inject "vrf_poll_interval", vrf_poll_interval]

[%%ifndef zkapp_cmd_limit]

let zkapp_cmd_limit = None

[%%else]

[%%inject "zkapp_cmd_limit", zkapp_cmd_limit]

let zkapp_cmd_limit = Some zkapp_cmd_limit

[%%endif]

[%%ifndef scan_state_tps_goal_x10]

let scan_state_tps_goal_x10 : int option = None

[%%else]

[%%inject "scan_state_tps_goal_x10", scan_state_tps_goal_x10]

let scan_state_tps_goal_x10 = Some scan_state_tps_goal_x10

[%%endif]

let genesis_constants : Genesis_constants.Inputs.t =
  { Genesis_constants.Inputs.genesis_state_timestamp
  ; k
  ; slots_per_epoch
  ; slots_per_sub_window
  ; grace_period_slots
  ; delta
  ; pool_max_size
  ; num_accounts = None
  ; zkapp_proof_update_cost
  ; zkapp_signed_single_update_cost
  ; zkapp_signed_pair_update_cost
  ; zkapp_transaction_cost_limit
  ; max_event_elements
  ; max_action_elements
  ; zkapp_cmd_limit_hardcap
  ; minimum_user_command_fee
  }

let constraint_constants : Genesis_constants.Constraint_constants.Inputs.t =
  { Genesis_constants.Constraint_constants.Inputs.scan_state_with_tps_goal
  ; scan_state_tps_goal_x10
  ; block_window_duration
  ; scan_state_transaction_capacity_log_2
  ; supercharged_coinbase_factor
  ; scan_state_work_delay
  ; coinbase
  ; account_creation_fee_int
  ; ledger_depth
  ; sub_windows_per_window
  ; fork = None
  }

let constraint_config =
  { Runtime_config.Json_layout.Constraint.constraint_constants; proof_level }

let compile_config : Mina_compile_config.Inputs.t =
  { curve_size
  ; default_transaction_fee_string = default_transaction_fee
  ; default_snark_worker_fee_string = default_snark_worker_fee
  ; minimum_user_command_fee_string = minimum_user_command_fee
  ; itn_features
  ; compaction_interval_ms = compaction_interval
  ; block_window_duration_ms = block_window_duration
  ; vrf_poll_interval_ms = vrf_poll_interval
  ; network_id = network
  ; zkapp_cmd_limit
  ; rpc_handshake_timeout_sec
  ; rpc_heartbeat_timeout_sec
  ; rpc_heartbeat_send_every_sec
  ; zkapp_proof_update_cost
  ; zkapp_signed_pair_update_cost
  ; zkapp_signed_single_update_cost
  ; zkapp_transaction_cost_limit
  ; max_event_elements
  ; max_action_elements
  ; zkapp_cmd_limit_hardcap
  ; zkapps_disabled
  ; slot_chain_end = None
  ; slot_tx_end = None
  }

let () =
  let filename =
    Sys.getenv_opt "MINA_CONFIG_FILE"
    |> Option.value_exn ~message:"Must must supply MINA_CONFIG_FILE env var"
  in
  let json = Yojson.Safe.from_file filename in
  let open Result.Let_syntax in
  let config =
    match json with
    | `Assoc obj ->
        let%bind ledger =
          List.Assoc.find obj "ledger" ~equal:String.equal
          |> Result.of_option ~error:"ledger not found"
          >>= Runtime_config.Json_layout.Ledger.of_yojson
        in
        let%map epoch_data =
          match List.Assoc.find obj "epoch_data" ~equal:String.equal with
          | None ->
              Ok None
          | Some v ->
              Result.map ~f:Option.some
              @@ Runtime_config.Json_layout.Epoch_data.of_yojson v
        in
        { Runtime_config.Json_layout.ledger
        ; epoch_data
        ; genesis = genesis_constants
        ; proof = constraint_config
        ; daemon = compile_config
        }
    | _ ->
        failwith "Invalid json file"
  in
  let json_layout : Runtime_config.Json_layout.t =
    Result.ok_or_failwith config
  in
  let out_filename = "runtime_config-" ^ network ^ ".json" in
  Yojson.Safe.to_file out_filename
    (Runtime_config.Json_layout.to_yojson json_layout)
