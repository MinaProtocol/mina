module type Version = sig
  val protocol_version_transaction : int

  val protocol_version_network : int

  val protocol_version_patch : int
end

module type S = sig
  include Version

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
end
