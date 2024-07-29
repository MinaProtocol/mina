type t = {
    ledger_depth : int
  ; curve_size : int
  ; coinbase : string
  ; k : int
  ; delta : int
  ; slots_per_epoch : int
  ; slots_per_sub_window : int
  ; sub_windows_per_window : int
  ; grace_period_slots : int
  ; scan_state_with_tps_goal : bool
  ; scan_state_transaction_capacity_log_2 : int option
  ; scan_state_work_delay : int
  ; debug_logs : bool
  ; call_logger : bool
  ; cache_exceptions : bool
  ; record_async_backtraces : bool
  ; proof_level : string
  ; pool_max_size : int
  ; account_creation_fee_int : string
  ; default_transaction_fee : string
  ; default_snark_worker_fee : string
  ; minimum_user_command_fee : string
  ; protocol_version_transaction : int
  ; protocol_version_network : int
  ; protocol_version_patch : int
  ; supercharged_coinbase_factor : int
  ; time_offsets : bool
  ; plugins : bool
  ; genesis_ledger : string
  ; genesis_state_timestamp : string
  ; block_window_duration : int
  ; integration_tests : bool
  ; force_updates : bool
  ; download_snark_keys : bool
  ; generate_genesis_proof : bool
  ; itn_features : bool
  ; compaction_interval : int option
  ; vrf_poll_interval : int
  ; network : string
  ; zkapp_cmd_limit : int option
  ; slot_tx_end : int option
  ; slot_chain_end : int option
  ; scan_state_tps_goal_x10 : int option
} [@@deriving to_yojson, of_yojson]

type network
  = Dev
  | Lightnet
  | Devnet
  | Mainnet

let read_network_env_var = 
  match Option.map String.lowercase_ascii @@ Sys.getenv_opt "MINA_NETWORK" with
    | Some "lightnet" -> Lightnet
    | Some "devnet" -> Devnet
    | Some "mainnet" -> Mainnet
    | _ -> Dev

let read_network_config config_dir= 
  let config_file = match read_network_env_var with
    | Dev -> "dev.json"
    | Lightnet -> "lightnet.json"
    | Devnet -> "devnet.json"
    | Mainnet -> "mainnet.json"
  in 
    Yojson.Safe.from_file (String.cat config_dir config_file)

let config = lazy (
  read_network_config "node_config/" |> of_yojson |> Result.get_ok
)

let get () = Lazy.force config

let ledger_depth = 
  let c = get ()
  in c.ledger_depth

let curve_size =
  let c = get ()
  in c.curve_size

let coinbase =
  let c = get ()
  in c.coinbase

let k =
  let c = get ()
  in c.k

let delta =
  let c = get ()
  in c.delta

let slots_per_epoch =
  let c = get ()
  in c.slots_per_epoch

let slots_per_sub_window =
  let c = get ()
  in c.slots_per_sub_window

let sub_windows_per_window =
  let c = get ()
  in c.sub_windows_per_window

let grace_period_slots =
  let c = get ()
  in c.grace_period_slots

let scan_state_with_tps_goal =
  let c = get ()
  in c.scan_state_with_tps_goal

let scan_state_transaction_capacity_log_2 =
  let c = get ()
  in c.scan_state_transaction_capacity_log_2

let scan_state_work_delay =
  let c = get ()
  in c.scan_state_work_delay

let debug_logs =
  let c = get ()
  in c.debug_logs

let call_logger =
  let c = get ()
  in c.call_logger

let cache_exceptions =
  let c = get ()
  in c.cache_exceptions

let record_async_backtraces =
  let c = get ()
  in c.record_async_backtraces

let proof_level =
  let c = get ()
  in c.proof_level


let pool_max_size =
  let c = get ()
  in c.pool_max_size

let account_creation_fee_int =
  let c = get ()
  in c.account_creation_fee_int

let default_transaction_fee =
  let c = get ()
  in c.default_transaction_fee

let default_snark_worker_fee =
  let c = get ()
  in c.default_snark_worker_fee

let minimum_user_command_fee =
  let c = get ()
  in c.minimum_user_command_fee

let protocol_version_transaction =
  let c = get ()
  in c.protocol_version_transaction

let protocol_version_network =
  let c = get ()
  in c.protocol_version_network

let protocol_version_patch =
  let c = get ()
  in c.protocol_version_patch

let supercharged_coinbase_factor =
  let c = get ()
  in c.supercharged_coinbase_factor

let time_offsets =
  let c = get ()
  in c.time_offsets

let plugins =
  let c = get ()
  in c.plugins

let genesis_ledger =
  let c = get ()
  in c.genesis_ledger

let genesis_state_timestamp =
  let c = get ()
  in c.genesis_state_timestamp

let block_window_duration =
  let c = get ()
  in c.block_window_duration

let integration_tests =
  let c = get ()
  in c.integration_tests

let force_updates =
  let c = get ()
  in c.force_updates

let download_snark_keys =
  let c = get ()
  in c.download_snark_keys

let generate_genesis_proof =
  let c = get ()
  in c.generate_genesis_proof

let itn_features =
  let c = get ()
  in c.itn_features

let compaction_interval =
  let c = get ()
  in c.compaction_interval

let vrf_poll_interval =
  let c = get ()
  in c.vrf_poll_interval

let network =
  let c = get ()
  in c.network

let zkapp_cmd_limit =
  let c = get ()
  in c.zkapp_cmd_limit

let slot_tx_end =
  let c = get ()
  in c.slot_tx_end

let slot_chain_end =
  let c = get ()
  in c.slot_chain_end

let scan_state_tps_goal_x10 =
  let c = get ()
  in c.scan_state_tps_goal_x10