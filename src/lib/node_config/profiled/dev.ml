let ledger_depth = 10

let curve_size = 255

let coinbase = "20"

let k = 24

let delta = 0

let slots_per_epoch = 576

let slots_per_sub_window = 2

let sub_windows_per_window = 3

let grace_period_slots = 180

let scan_state_transaction_capacity_log_2 = 3

let scan_state_work_delay = 2

let proof_level = "check"

(* Note this value needs to be consistent across nodes to prevent spurious bans.
   see comment in transaction_pool.ml for more details. *)
let pool_max_size = 3000

let account_creation_fee_int = "0.001"

let default_transaction_fee = "5"

let default_snark_worker_fee = "1"

let minimum_user_command_fee = "2"

let supercharged_coinbase_factor = 1

let plugins = true

let genesis_state_timestamp = "2019-01-30 12:00:00-08:00"

let block_window_duration = 2000

let network = "testnet"

let profile = "dev"

let compaction_interval = None

let vrf_poll_interval = 0

let zkapp_cmd_limit = None

let sync_ledger_max_subtree_depth = 4

let sync_ledger_default_subtree_depth = 3
