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

let zkapp_proof_update_cost = Node_config.zkapp_proof_update_cost

let zkapp_signed_pair_update_cost = Node_config.zkapp_signed_pair_update_cost

let zkapp_signed_single_update_cost =
  Node_config.zkapp_signed_single_update_cost

let zkapp_transaction_cost_limit = Node_config.zkapp_transaction_cost_limit

let max_event_elements = Node_config.max_event_elements

let max_action_elements = Node_config.max_action_elements

let network_id = Node_config.network

let zkapp_cmd_limit = Node_config.zkapp_cmd_limit

let zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap

let zkapps_disabled = false

let slot_tx_end : int option = Node_config.slot_tx_end

let slot_chain_end : int option = Node_config.slot_chain_end
