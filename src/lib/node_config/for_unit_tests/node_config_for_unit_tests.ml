(** This file consists of compile-time constants that are not in Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

include Node_config_version

let (ledger_depth : int) = (10 : int)

let (curve_size : int) = (255 : int)

let (coinbase : string) = ("20" : string)

let (k : int) = (24 : int)

let (delta : int) = (0 : int)

let (slots_per_epoch : int) = (576 : int)

let (slots_per_sub_window : int) = (2 : int)

let (sub_windows_per_window : int) = (3 : int)

let (grace_period_slots : int) = (180 : int)

let (scan_state_with_tps_goal : bool) = (false : bool)

let (scan_state_transaction_capacity_log_2 : int) = (3 : int)

let scan_state_transaction_capacity_log_2 =
  Some scan_state_transaction_capacity_log_2

let (scan_state_work_delay : int) = (2 : int)

let (proof_level : string) = ("check" : string)

let (pool_max_size : int) = (3000 : int)

let (account_creation_fee_int : string) = ("0.001" : string)

let (default_snark_worker_fee : string) = ("1" : string)

let (minimum_user_command_fee : string) = ("2" : string)

let (supercharged_coinbase_factor : int) = (1 : int)

let (plugins : bool) = (true : bool)

let (genesis_state_timestamp : string) = ("2019-01-30 12:00:00-08:00" : string)

let (block_window_duration : int) = (2000 : int)

let (itn_features : bool) = (true : bool)

let compaction_interval = None

let (network : string) = ("testnet" : string)

let (vrf_poll_interval : int) = (0 : int)

let zkapp_cmd_limit = None

let scan_state_tps_goal_x10 : int option = None

(** limits on Zkapp_command.t size
    10.26*np + 10.08*n2 + 9.14*n1 < 69.45
    where np: number of single proof updates
    n2: number of pairs of signed/no-auth update
    n1: number of single signed/no-auth update
    and their coefficients representing the cost
  The formula was generated based on benchmarking data conducted on bare
  metal i9 processor with room to include lower spec.
  69.45 was the total time for a combination of updates that was considered
  acceptable.
  The method used to estimate the cost was linear least squares.
*)

let zkapp_proof_update_cost = 10.26

let zkapp_signed_pair_update_cost = 10.08

let zkapp_signed_single_update_cost = 9.14

let zkapp_transaction_cost_limit = 69.45

let max_event_elements = 100

let max_action_elements = 100

let zkapp_cmd_limit_hardcap = 128

let zkapps_disabled = false

let rpc_handshake_timeout_sec = 60.0

let rpc_heartbeat_timeout_sec = 60.0

let rpc_heartbeat_send_every_sec = 10.0 (*same as the default*)
