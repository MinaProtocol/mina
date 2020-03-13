[%%import
"/src/config.mlh"]

(*Deepthi: This should only consists of compile time constants that are not in Coda_constants. i.e., all the constants that are defined at compile-time for both tests and production*)
[%%inject
"proof_level", proof_level]

[%%inject
"coinbase_int", coinbase]

[%%inject
"curve_size", curve_size]

[%%inject
"fake_accounts_target", fake_accounts_target]

[%%inject
"genesis_ledger", genesis_ledger]

[%%inject
"ledger_depth", ledger_depth]

[%%inject
"pool_max_size", pool_max_size]

[%%inject
"account_creation_fee_int", account_creation_fee_int]

[%%inject
"k", k]

[%%inject
"c", c]

[%%inject
"delta", delta]

let coinbase = Currency.Amount.of_int coinbase_int

let account_creation_fee = Currency.Fee.of_int account_creation_fee_int

[%%inject
"work_delay", scan_state_work_delay]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal_x10", scan_state_tps_goal_x10]

let scan_state_capacity = `Tps_goal_x10 tps_goal_x10

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

let scan_state_capacity =
  `Transaction_capacity_log_2 transaction_capacity_log_2

[%%endif]

[%%inject
"block_window_duration_ms", block_window_duration]

[%%inject
"genesis_state_timestamp_string", genesis_state_timestamp]
