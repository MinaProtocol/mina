(** This file consists of compile-time constants that are not in Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

include Node_config_version
include Node_config_unconfigurable_constants

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

let (default_transaction_fee : string) = ("5" : string)

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

let sync_ledger_max_subtree_depth = 4

let sync_ledger_default_subtree_depth = 3
