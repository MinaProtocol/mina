[%%import
"../../config.mlh"]

(* in the config files, we either have:

    - a work_delay and transaction_capacity_log_2, or
    - a work_delay and a tps_goal, allowing us to calculate transaction_capacity_log_2

   use the config boolean scan_state_with_tps_goal to distinguish those cases
*)

module type S = Scan_state_constants_intf.S

[%%inject
"work_delay", scan_state_work_delay]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal", scan_state_tps_goal]

[%%inject
"block_window_duration", block_window_duration]

let max_coinbases = 2

let max_user_commands_per_block = tps_goal * block_window_duration / 1000

let transaction_capacity_log_2 =
  1 + Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%endif]
