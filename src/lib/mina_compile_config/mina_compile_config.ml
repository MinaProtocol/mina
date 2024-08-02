(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

let curve_size = Node_config.curve_size

let default_transaction_fee_string = Node_config.default_transaction_fee

let default_snark_worker_fee_string = Node_config.default_snark_worker_fee

let minimum_user_command_fee_string = Node_config.minimum_user_command_fee

let itn_features = Node_config.itn_features

let compaction_interval_ms = Node_config.compaction_interval

let block_window_duration_ms = Node_config.block_window_duration

let vrf_poll_interval_ms = Node_config.vrf_poll_interval

let rpc_handshake_timeout_sec = 60.0

let rpc_heartbeat_timeout_sec = 60.0

let rpc_heartbeat_send_every_sec = 10.0 (*same as the default*)

(** limits on Zkapp_command.t size
    10.26*np + 10.08*n2 + 9.14*n1 < 69.45
    where np: number of single proof updates
    n2: number of pairs of signed/no-auth update
    n1: number of single signed/no-auth update
    and their coefficients representing the cost
  The formula was generated based on benchmarking data conducted on bare
  metal i9 processor with room to include lower spec.
  69.45 was the total time for a combination of updates that was considered
  acceptable.
  The method used to estimate the cost was linear least squares.
*)

let zkapp_proof_update_cost = 10.26

let zkapp_signed_pair_update_cost = 10.08

let zkapp_signed_single_update_cost = 9.14

let zkapp_transaction_cost_limit = 69.45

let max_event_elements = 100

let max_action_elements = 100

let network_id = Node_config.network

let zkapp_cmd_limit = Node_config.zkapp_cmd_limit

let zkapp_cmd_limit_hardcap = 128

let zkapps_disabled = false

let slot_tx_end : int option = Node_config.slot_tx_end

let slot_chain_end : int option = Node_config.slot_chain_end
