module type Version = sig
  val protocol_version_transaction : int

  val protocol_version_network : int

  val protocol_version_patch : int
end

(* It's stupid that this exists. TODO: Remove and make configurable. *)
module type Unconfigurable_constants = sig
  val zkapp_proof_update_cost : float

  val zkapp_signed_pair_update_cost : float

  val zkapp_signed_single_update_cost : float

  val zkapp_transaction_cost_limit : float

  val max_event_elements : int

  val max_action_elements : int

  val zkapp_cmd_limit_hardcap : int

  val zkapps_disabled : bool

  val rpc_handshake_timeout_sec : float

  val rpc_heartbeat_timeout_sec : float

  val rpc_heartbeat_send_every_sec : float
end

module type S = sig
  include Version

  include Unconfigurable_constants

  val ledger_depth : int

  val curve_size : int

  val coinbase : string

  val k : int

  val delta : int

  val slots_per_epoch : int

  val slots_per_sub_window : int

  val sub_windows_per_window : int

  val grace_period_slots : int

  val scan_state_with_tps_goal : bool

  val scan_state_transaction_capacity_log_2 : int option

  val scan_state_work_delay : int

  val proof_level : string

  val pool_max_size : int

  val account_creation_fee_int : string

  val default_transaction_fee : string

  val default_snark_worker_fee : string

  val minimum_user_command_fee : string

  val supercharged_coinbase_factor : int

  val plugins : bool

  val genesis_state_timestamp : string

  val block_window_duration : int

  val itn_features : bool

  val compaction_interval : int option

  val vrf_poll_interval : int

  val network : string

  val zkapp_cmd_limit : int option

  val scan_state_tps_goal_x10 : int option

  val sync_ledger_max_subtree_depth : int

  val sync_ledger_default_subtree_depth : int
end
