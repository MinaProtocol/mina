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
[%%inject "scan_state_transaction_capacity_log_2", scan_state_transaction_capacity_log_2]
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