[%%import "/src/config.mlh"]

(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

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

[%%inject "debug_logs", debug_logs]

[%%inject "call_logger", call_logger]

[%%inject "cache_exceptions", cache_exceptions]

[%%inject "record_async_backtraces", record_async_backtraces]

[%%inject "proof_level", proof_level]

[%%inject "pool_max_size", pool_max_size]

[%%inject "account_creation_fee_int", account_creation_fee_int]

[%%inject "default_transaction_fee", default_transaction_fee]

[%%inject "default_snark_worker_fee", default_snark_worker_fee]

[%%inject "minimum_user_command_fee", minimum_user_command_fee]

[%%inject "protocol_version_transaction", protocol_version_transaction]

[%%inject "protocol_version_network", protocol_version_network]

[%%inject "protocol_version_patch", protocol_version_patch]

[%%inject "supercharged_coinbase_factor", supercharged_coinbase_factor]

[%%inject "time_offsets", time_offsets]

[%%inject "plugins", plugins]

[%%inject "genesis_ledger", genesis_ledger]

[%%inject "genesis_state_timestamp", genesis_state_timestamp]

[%%inject "block_window_duration", block_window_duration]

[%%inject "integration_tests", integration_tests]

[%%inject "force_updates", force_updates]

[%%inject "download_snark_keys", download_snark_keys]

[%%inject "generate_genesis_proof", generate_genesis_proof]

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

[%%ifndef slot_tx_end]

let slot_tx_end : int option = None

[%%else]

[%%inject "slot_tx_end", slot_tx_end]

let slot_tx_end = Some slot_tx_end

[%%endif]

[%%ifndef slot_chain_end]

let slot_chain_end : int option = None

[%%else]

[%%inject "slot_chain_end", slot_chain_end]

let slot_chain_end = Some slot_chain_end

[%%endif]

[%%ifndef scan_state_tps_goal_x10]

let scan_state_tps_goal_x10 : int option = None

[%%else]

[%%inject "scan_state_tps_goal_x10", scan_state_tps_goal_x10]

let scan_state_tps_goal_x10 = Some scan_state_tps_goal_x10

[%%endif]

(*
let load_config_file filename =
  let open Deferred.Or_error.Let_syntax in
  Monitor.try_with_join_or_error ~here:[%here] (fun () ->
      let%map json = load_config_json filename in
      match Runtime_config.of_yojson json with
      | Ok config ->
          Ok config
      | Error err ->
          Or_error.error_string err )

*)

type t = {
    ledger_depth : int
  ; curve_size : int
  ; coinbase : string
  ; k : int
  ; delta : int
  ; slots_per_epoch : int
  ; slots_per_sub_window : int
  ; sub_windows_per_window : int
  ; grace_period_slots : int
  ; scan_state_with_tps_goal : bool
  ; scan_state_transaction_capacity_log_2 : int option
  ; scan_state_work_delay : int
  ; debug_logs : bool
  ; call_logger : bool
  ; cache_exceptions : bool
  ; record_async_backtraces : bool
  ; proof_level : string
  ; pool_max_size : int
  ; account_creation_fee_int : string
  ; default_transaction_fee : string
  ; default_snark_worker_fee : string
  ; minimum_user_command_fee : string
  ; protocol_version_transaction : int
  ; protocol_version_network : int
  ; protocol_version_patch : int
  ; supercharged_coinbase_factor : int
  ; time_offsets : bool
  ; plugins : bool
  ; genesis_ledger : string
  ; genesis_state_timestamp : string
  ; block_window_duration : int
  ; integration_tests : bool
  ; force_updates : bool
  ; download_snark_keys : bool
  ; generate_genesis_proof : bool
  ; itn_features : bool
  ; compaction_interval : int option
  ; vrf_poll_interval : int
  ; network : string
  ; zkapp_cmd_limit : int option
  ; slot_tx_end : int option
  ; slot_chain_end : int option
  ; scan_state_tps_goal_x10 : int option
} [@@deriving to_yojson, of_yojson]

let config: t = 
  { ledger_depth
  ; curve_size
  ; coinbase
  ; k
  ; delta
  ; slots_per_epoch
  ; slots_per_sub_window
  ; sub_windows_per_window
  ; grace_period_slots
  ; scan_state_with_tps_goal
  ; scan_state_transaction_capacity_log_2
  ; scan_state_work_delay
  ; debug_logs
  ; call_logger
  ; cache_exceptions
  ; record_async_backtraces
  ; proof_level
  ; pool_max_size
  ; account_creation_fee_int
  ; default_transaction_fee
  ; default_snark_worker_fee
  ; minimum_user_command_fee
  ; protocol_version_transaction
  ; protocol_version_network
  ; protocol_version_patch
  ; supercharged_coinbase_factor
  ; time_offsets
  ; plugins
  ; genesis_ledger
  ; genesis_state_timestamp
  ; block_window_duration
  ; integration_tests
  ; force_updates
  ; download_snark_keys
  ; generate_genesis_proof
  ; itn_features
  ; compaction_interval
  ; vrf_poll_interval
  ; network
  ; zkapp_cmd_limit
  ; slot_tx_end
  ; slot_chain_end
  ; scan_state_tps_goal_x10
  }

let () = to_yojson config |> Yojson.Safe.pretty_to_string |> print_endline