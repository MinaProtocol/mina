(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

open Core_kernel

type t =
  { curve_size : int
  ; default_transaction_fee_string : string
  ; default_snark_worker_fee_string : string
  ; minimum_user_command_fee_string : string
  ; itn_features : bool
  ; compaction_interval_ms : int option
  ; block_window_duration_ms : int
  ; vrf_poll_interval_ms : int
  ; network_id : string
  ; zkapp_cmd_limit : int option
  ; rpc_handshake_timeout_sec : float
  ; rpc_heartbeat_timeout_sec : float
  ; rpc_heartbeat_send_every_sec : float
  ; zkapp_proof_update_cost : float
  ; zkapp_signed_pair_update_cost : float
  ; zkapp_signed_single_update_cost : float
  ; zkapp_transaction_cost_limit : float
  ; max_event_elements : int
  ; max_action_elements : int
  ; zkapp_cmd_limit_hardcap : int
  ; zkapps_disabled : bool
  }
[@@deriving bin_io_unversioned, to_yojson]

(*TODO: Delete this module and read in a value from the environment*)
module Compiled = struct
  let t : t =
    { curve_size = Node_config.curve_size
    ; default_transaction_fee_string = Node_config.default_transaction_fee
    ; default_snark_worker_fee_string = Node_config.default_snark_worker_fee
    ; minimum_user_command_fee_string = Node_config.minimum_user_command_fee
    ; itn_features = Node_config.itn_features
    ; compaction_interval_ms = Node_config.compaction_interval
    ; block_window_duration_ms = Node_config.block_window_duration
    ; vrf_poll_interval_ms = Node_config.vrf_poll_interval
    ; rpc_handshake_timeout_sec = Node_config.rpc_handshake_timeout_sec
    ; rpc_heartbeat_timeout_sec = Node_config.rpc_heartbeat_timeout_sec
    ; rpc_heartbeat_send_every_sec = Node_config.rpc_heartbeat_send_every_sec
    ; zkapp_proof_update_cost = Node_config.zkapp_proof_update_cost
    ; zkapp_signed_pair_update_cost = Node_config.zkapp_signed_pair_update_cost
    ; zkapp_signed_single_update_cost =
        Node_config.zkapp_signed_single_update_cost
    ; zkapp_transaction_cost_limit = Node_config.zkapp_transaction_cost_limit
    ; max_event_elements = Node_config.max_event_elements
    ; max_action_elements = Node_config.max_action_elements
    ; network_id = Node_config.network
    ; zkapp_cmd_limit = Node_config.zkapp_cmd_limit
    ; zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap
    ; zkapps_disabled = Node_config.zkapps_disabled
    }
end

module For_unit_tests = struct
  let t : t =
    { curve_size = Node_config_for_unit_tests.curve_size
    ; default_transaction_fee_string =
        Node_config_for_unit_tests.default_transaction_fee
    ; default_snark_worker_fee_string =
        Node_config_for_unit_tests.default_snark_worker_fee
    ; minimum_user_command_fee_string =
        Node_config_for_unit_tests.minimum_user_command_fee
    ; itn_features = Node_config_for_unit_tests.itn_features
    ; compaction_interval_ms = Node_config_for_unit_tests.compaction_interval
    ; block_window_duration_ms =
        Node_config_for_unit_tests.block_window_duration
    ; vrf_poll_interval_ms = Node_config_for_unit_tests.vrf_poll_interval
    ; rpc_handshake_timeout_sec =
        Node_config_for_unit_tests.rpc_handshake_timeout_sec
    ; rpc_heartbeat_timeout_sec =
        Node_config_for_unit_tests.rpc_heartbeat_timeout_sec
    ; rpc_heartbeat_send_every_sec =
        Node_config_for_unit_tests.rpc_heartbeat_send_every_sec
    ; zkapp_proof_update_cost =
        Node_config_for_unit_tests.zkapp_proof_update_cost
    ; zkapp_signed_pair_update_cost =
        Node_config_for_unit_tests.zkapp_signed_pair_update_cost
    ; zkapp_signed_single_update_cost =
        Node_config_for_unit_tests.zkapp_signed_single_update_cost
    ; zkapp_transaction_cost_limit =
        Node_config_for_unit_tests.zkapp_transaction_cost_limit
    ; max_event_elements = Node_config_for_unit_tests.max_event_elements
    ; max_action_elements = Node_config_for_unit_tests.max_action_elements
    ; network_id = Node_config_for_unit_tests.network
    ; zkapp_cmd_limit = Node_config_for_unit_tests.zkapp_cmd_limit
    ; zkapp_cmd_limit_hardcap =
        Node_config_for_unit_tests.zkapp_cmd_limit_hardcap
    ; zkapps_disabled = Node_config_for_unit_tests.zkapps_disabled
    }
end
