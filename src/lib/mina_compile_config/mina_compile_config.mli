val curve_size : int

val genesis_ledger : string

val default_transaction_fee_string : string

val default_snark_worker_fee_string : string

val minimum_user_command_fee_string : string

val itn_features : bool

val compaction_interval_ms : int option

val block_window_duration_ms : int

val vrf_poll_interval_ms : int

val rpc_handshake_timeout_sec : float

val rpc_heartbeat_timeout_sec : float

val rpc_heartbeat_send_every_sec : float

val zkapp_proof_update_cost : float

val zkapp_signed_pair_update_cost : float

val zkapp_signed_single_update_cost : float

val zkapp_transaction_cost_limit : float

val max_event_elements : int

val max_action_elements : int

val network_id : string

val zkapp_cmd_limit : int option

val zkapp_cmd_limit_hardcap : int

val zkapps_disabled : bool

val slot_tx_end : int option

val slot_chain_end : int option

val handle_unconsumed_cache_item : logger:Logger.t -> cache_name:string -> unit

module Time_controller : module type of Time_controller.T

module type Time_controller_intf = Time_controller_intf.S

val with_plugins : bool
