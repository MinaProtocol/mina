[%%import
"/src/config.mlh"]

[%%ifndef
consensus_mechanism]

module Currency = Currency_nonconsensus.Currency

[%%endif]

(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

[%%inject
"curve_size", curve_size]

[%%inject
"genesis_ledger", genesis_ledger]

[%%inject
"account_creation_fee_string", account_creation_fee_int]

[%%inject
"default_transaction_fee_string", default_transaction_fee]

[%%inject
"default_snark_worker_fee_string", default_snark_worker_fee]

[%%inject
"minimum_user_command_fee_string", minimum_user_command_fee]

let account_creation_fee =
  Currency.Fee.of_formatted_string account_creation_fee_string

let minimum_user_command_fee =
  Currency.Fee.of_formatted_string minimum_user_command_fee_string

let default_transaction_fee =
  Currency.Fee.of_formatted_string default_transaction_fee_string

let default_snark_worker_fee =
  Currency.Fee.of_formatted_string default_snark_worker_fee_string

(** All the proofs before the last [work_delay] blocks must be completed to add
    transactions. [work_delay] is the minimum number of blocks and will
    increase if the throughput is less.
    - If [work_delay = 0], all the work that was added to the scan state in the
      previous block is expected to be completed and included in the current
      block if any transactions/coinbase are to be included.
    - [work_delay >= 1] means that there's at least two block times for
      completing the proofs.
*)

[%%inject
"work_delay", scan_state_work_delay]

[%%inject
"block_window_duration_ms", block_window_duration]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal_x10", scan_state_tps_goal_x10]

let max_coinbases = 2

(* block_window_duration is in milliseconds, so divide by 1000
   divide by 10 again because we have tps * 10
*)
let max_user_commands_per_block =
  tps_goal_x10 * block_window_duration_ms / (1000 * 10)

(** Log of the capacity of transactions per transition.
    - 1 will only work if we don't have prover fees.
    - 2 will work with prover fees, but not if we want a transaction included
      in every block.
    - At least 3 ensures a transaction per block and the staged-ledger unit
      tests pass.
*)
let transaction_capacity_log_2 =
  1 + Core_kernel.Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%endif]

let pending_coinbase_depth =
  Core_kernel.Int.ceil_log2
    (((transaction_capacity_log_2 + 1) * (work_delay + 1)) + 1)

(* This is a bit of a hack, see #3232. *)
let inactivity_ms = block_window_duration_ms * 8
