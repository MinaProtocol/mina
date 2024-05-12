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

type signature_kind_t = Mina_compile_config_intf.signature_kind_t

val signature_kind : signature_kind_t

module type Time_controller_intf = Mina_compile_config_intf.Time_controller_intf

module Time_controller : functor
  (F : sig
     type time

     type span

     val to_span_since_epoch : time -> span

     val of_span_since_epoch : span -> time

     val of_time_span : Core_kernel.Time.Span.t -> span

     val of_time : Core_kernel.Time.t -> time

     val ( + ) : span -> span -> span
   end)
  -> sig
  include Time_controller_intf

  val to_system_time : t -> F.time -> F.time

  val now : t -> F.time
end

module Genesis_constants : sig
  module Proof_level : sig
    val compiled : Genesis_constants.Proof_level.t

    val for_unit_tests : Genesis_constants.Proof_level.t
  end

  module Constraint_constants : sig
    val fork : Genesis_constants.Fork_constants.t option

    val compiled : Genesis_constants.Constraint_constants.t

    val for_unit_tests : Genesis_constants.Constraint_constants.t
  end

  val genesis_time : Core_kernel.Time.t

  val compiled : Genesis_constants.t

  val for_unit_tests : Genesis_constants.t
end
