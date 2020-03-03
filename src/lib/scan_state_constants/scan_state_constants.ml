[%%import
"/src/config.mlh"]

(* in the config files, we either have:

    - a work_delay and transaction_capacity_log_2, or
    - a work_delay and a tps_goal_x10 (transactions per second times 10), allowing us to calculate
       transaction_capacity_log_2

   use the config boolean scan_state_with_tps_goal to distinguish those cases
*)

open Core_kernel

module type S = Scan_state_constants_intf.S

[%%inject
"work_delay", scan_state_work_delay]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal_x10", scan_state_tps_goal_x10]

[%%inject
"block_window_duration", block_window_duration]

let max_coinbases = 2

(* block_window_duration is in milliseconds, so divide by 1000
   divide by 10 again because we have tps * 10
 *)
let max_user_commands_per_block =
  tps_goal_x10 * block_window_duration / (1000 * 10)

let transaction_capacity_log_2 =
  1 + Core_kernel.Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%endif]

(*Log of maximum number of trees in the parallel scan state*)
let pending_coinbase_depth =
  Int.ceil_log2 (((transaction_capacity_log_2 + 1) * (work_delay + 1)) + 1)
