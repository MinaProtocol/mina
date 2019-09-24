[%%import
"../../config.mlh"]

(* in the config files, we either have:

    - transaction_capacity_log_2 and work_delay exp explicitly, or
    - those are calculated from the tps_goal and num_snark_workers

   use the config boolean scan_state_calc_params to distinguish those cases

 *)

module type S = Scan_state_constants_intf.S

[%%if
scan_state_calc_params]

open Core_kernel

[%%inject
"tps_goal", scan_state_tps_goal]

[%%inject
"num_snark_workers", scan_state_num_snark_workers]

[%%inject
"block_window_duration", block_window_duration]

let max_coinbases = 2

let max_user_commands_per_block = tps_goal * block_window_duration

let transaction_capacity_log_2 =
  1 + Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

let work_delay = Int.pow 2 transaction_capacity_log_2 / num_snark_workers

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%inject
"work_delay", scan_state_work_delay]

[%%endif]
