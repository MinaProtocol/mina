let ledger_depth = 35

let curve_size = 255

let coinbase = "360"

let k = 30

let delta = 0

let slots_per_epoch = 720

let slots_per_sub_window = 7

let sub_windows_per_window = 11

let grace_period_slots = 200

let scan_state_transaction_capacity_log_2 = 3

let scan_state_work_delay = 2

let proof_level = "none"

(* Note this value needs to be consistent across nodes to prevent spurious bans.
   see comment in transaction_pool.ml for more details. *)
let pool_max_size = 3000

let account_creation_fee_int = "1.0"

let default_transaction_fee = "0.25"

let default_snark_worker_fee = "0.1"

let minimum_user_command_fee = "0.001"

let supercharged_coinbase_factor = 1

let plugins = false

let genesis_state_timestamp = "2020-09-16 03:15:00-07:00"

let block_window_duration = 20000

let network = "testnet"

let profile = "lightnet"

let compaction_interval = Some (2 * block_window_duration)

let vrf_poll_interval = 5000

let zkapp_cmd_limit = None

let sync_ledger_max_subtree_depth = 8

let sync_ledger_default_subtree_depth = 6
