[%%import "/src/config.mlh"]

(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

include Node_config_version

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

[%%inject "default_snark_worker_fee", default_snark_worker_fee]

[%%inject "minimum_user_command_fee", minimum_user_command_fee]

[%%inject "supercharged_coinbase_factor", supercharged_coinbase_factor]

[%%inject "plugins", plugins]

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
