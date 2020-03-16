[%%import
"/src/config.mlh"]

(*This file consists of compile time constants that are not in Coda_constants. i.e., all the constants that are defined at compile-time for both tests and production*)
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
"account_creation_fee_int", account_creation_fee_int]

let coinbase = Currency.Amount.of_int coinbase_int

let account_creation_fee = Currency.Fee.of_int account_creation_fee_int

(*transaction_capacity_log_2: Log of the capacity of transactions per
transition. 1 will only work if we don't have prover fees. 2 will work with
prover fees, but not if we want a transaction included in every block. At least 
3 ensures a transaction per block and the staged-ledger unit tests pass.
work_delay: All the proofs before the last <work_delay> blocks are required to
be completed to add transactions. <work_delay> is the minimum number of blocks
and will increase if the throughput is less. If delay = 0, then all the work
that was added to the scan state in the previous block is expected to be
completed and included in the current block if any transactions/coinbase are to
be included. Having a delay >= 1 means there's at least two block times for
completing the proofs *)
[%%inject
"work_delay", scan_state_work_delay]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal_x10", scan_state_tps_goal_x10]

[%%inject
"block_window_duration_ms", block_window_duration]

let max_coinbases = 2

(* block_window_duration is in milliseconds, so divide by 1000
       divide by 10 again because we have tps * 10
     *)
let max_user_commands_per_block =
  tps_goal_x10 * block_window_duration_ms / (1000 * 10)

let transaction_capacity_log_2 =
  1 + Core_kernel.Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%endif]

let pending_coinbase_depth =
  Core_kernel.Int.ceil_log2
    (((transaction_capacity_log_2 + 1) * (work_delay + 1)) + 1)

(*Consensus constants*)
[%%inject
"c", c]

let sub_windows_per_window = c
