val curve_size : int

val genesis_ledger : string

val default_transaction_fee : Currency.Fee.t

val default_snark_worker_fee : Currency.Fee.t

val minimum_user_command_fee : Currency.Fee.t

val itn_features : bool

val compaction_interval_ms : int option

val block_window_duration_ms : int

val vrf_poll_interval_ms : int

val rpc_handshake_timeout_sec : float

val rpc_heartbeat_timeout_sec : float

val rpc_heartbeat_send_every_sec : float

val network_id : string

val zkapp_cmd_limit : int option

val zkapps_disabled : bool

val slot_tx_end : int option

val slot_chain_end : int option

val handle_unconsumed_cache_item : logger:Logger.t -> cache_name:string -> unit

val with_plugins : bool

val current_protocol_version : Protocol_version.t

val current_txn_version : Mina_numbers.Txn_version.t

module Time_controller : module type of Time_controller.T

module type Time_controller_intf = Time_controller_intf.S

module Genesis_constants : module type of Genesis
