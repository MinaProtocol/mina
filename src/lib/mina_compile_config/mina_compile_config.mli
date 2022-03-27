val curve_size : int

val genesis_ledger : string

val default_transaction_fee_string : string

val default_snark_worker_fee_string : string

val minimum_user_command_fee_string : string

val compaction_interval_ms : 'a option

val minimum_user_command_fee : Currency.Fee.Stable.Latest.t

val default_transaction_fee : Currency.Fee.Stable.Latest.t

val default_snark_worker_fee : Currency.Fee.Stable.Latest.t

val block_window_duration_ms : int

val vrf_poll_interval_ms : int

val rpc_handshake_timeout_sec : float

val rpc_heartbeat_timeout_sec : float

val rpc_heartbeat_send_every_sec : float

val generate_genesis_proof : bool
