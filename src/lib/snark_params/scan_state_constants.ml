[%%import
"../../config.mlh"]

(* in the config files, we either have:

    - transaction_capacity_log_2 and work_delay exp explicitly, or
    - those same parameters, and a tps_goal

   use the config boolean scan_state_with_tps_goal to distinguish those cases

   If the tps_goal is given, then we can calculate a desired number of snark
   workers.

*)

module type S = Scan_state_constants_intf.S

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

[%%inject
"work_delay", scan_state_work_delay]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal", scan_state_tps_goal]

let number_of_snark_workers () =
  Int.pow 2 transaction_capacity_log_2 / work_delay

[%%endif]
