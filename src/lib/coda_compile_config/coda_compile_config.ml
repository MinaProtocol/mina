[%%import
"../../config.mlh"]

[%%inject
"proof_level", proof_level]

[%%inject
"coinbase_int", coinbase]

let coinbase = Currency.Amount.of_int coinbase_int

[%%inject
"scan_state_transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%inject
"scan_state_work_delay", scan_state_work_delay]
