(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

open Core_kernel

module Inputs = struct
  type t =
    { curve_size : int
    ; default_transaction_fee_string : string
    ; default_snark_worker_fee_string : string
    ; minimum_user_command_fee_string : string
    ; compaction_interval_ms : int option
    ; block_window_duration_ms : int
    ; vrf_poll_interval_ms : int
    ; network_id : string
    ; zkapp_cmd_limit : int option
    ; rpc_handshake_timeout_sec : float
    ; rpc_heartbeat_timeout_sec : float
    ; rpc_heartbeat_send_every_sec : float
    ; max_zkapp_segment_per_transaction : int
    ; max_event_elements : int
    ; max_action_elements : int
    ; zkapp_cmd_limit_hardcap : int
    ; zkapps_disabled : bool
    ; sync_ledger_max_subtree_depth : int
    ; sync_ledger_default_subtree_depth : int
    }
  [@@deriving yojson, bin_io_unversioned]
end

type t =
  { curve_size : int
  ; default_transaction_fee : Currency.Fee.Stable.Latest.t
  ; default_snark_worker_fee : Currency.Fee.Stable.Latest.t
  ; minimum_user_command_fee : Currency.Fee.Stable.Latest.t
  ; compaction_interval : Time.Span.t option
  ; block_window_duration : Time.Span.t
  ; vrf_poll_interval : Time.Span.t
  ; network_id : string
  ; zkapp_cmd_limit : int option
  ; rpc_handshake_timeout : Time.Span.t
  ; rpc_heartbeat_timeout : Time.Span.t
  ; rpc_heartbeat_send_every : Time.Span.t
  ; max_zkapp_segment_per_transaction : int
  ; max_event_elements : int
  ; max_action_elements : int
  ; zkapp_cmd_limit_hardcap : int
  ; zkapps_disabled : bool
  ; sync_ledger_max_subtree_depth : int
  ; sync_ledger_default_subtree_depth : int
  }
[@@deriving sexp_of, bin_io_unversioned]

let make (inputs : Inputs.t) =
  { curve_size = inputs.curve_size
  ; default_transaction_fee =
      Currency.Fee.of_mina_string_exn inputs.default_transaction_fee_string
  ; default_snark_worker_fee =
      Currency.Fee.of_mina_string_exn inputs.default_snark_worker_fee_string
  ; minimum_user_command_fee =
      Currency.Fee.of_mina_string_exn inputs.minimum_user_command_fee_string
  ; compaction_interval =
      Option.map
        ~f:(fun x -> Float.of_int x |> Time.Span.of_ms)
        inputs.compaction_interval_ms
  ; block_window_duration =
      Float.of_int inputs.block_window_duration_ms |> Time.Span.of_ms
  ; vrf_poll_interval =
      Float.of_int inputs.vrf_poll_interval_ms |> Time.Span.of_ms
  ; rpc_handshake_timeout = Time.Span.of_sec inputs.rpc_handshake_timeout_sec
  ; rpc_heartbeat_timeout = Time.Span.of_sec inputs.rpc_heartbeat_timeout_sec
  ; rpc_heartbeat_send_every =
      Time.Span.of_sec inputs.rpc_heartbeat_send_every_sec
  ; max_zkapp_segment_per_transaction = inputs.max_zkapp_segment_per_transaction
  ; max_event_elements = inputs.max_event_elements
  ; max_action_elements = inputs.max_action_elements
  ; network_id = inputs.network_id
  ; zkapp_cmd_limit = inputs.zkapp_cmd_limit
  ; zkapp_cmd_limit_hardcap = inputs.zkapp_cmd_limit_hardcap
  ; zkapps_disabled = inputs.zkapps_disabled
  ; sync_ledger_max_subtree_depth = inputs.sync_ledger_max_subtree_depth
  ; sync_ledger_default_subtree_depth = inputs.sync_ledger_default_subtree_depth
  }

let to_yojson t =
  `Assoc
    [ ("curve_size", `Int t.curve_size)
    ; ( "default_transaction_fee"
      , Currency.Fee.to_yojson t.default_transaction_fee )
    ; ( "default_snark_worker_fee"
      , Currency.Fee.to_yojson t.default_snark_worker_fee )
    ; ( "minimum_user_command_fee"
      , Currency.Fee.to_yojson t.minimum_user_command_fee )
    ; ( "compaction_interval"
      , Option.value_map ~default:`Null
          ~f:(fun x -> `Float (Time.Span.to_ms x))
          t.compaction_interval )
    ; ("block_window_duration", `Float (Time.Span.to_ms t.block_window_duration))
    ; ("vrf_poll_interval", `Float (Time.Span.to_ms t.vrf_poll_interval))
    ; ( "rpc_handshake_timeout"
      , `Float (Time.Span.to_sec t.rpc_handshake_timeout) )
    ; ( "rpc_heartbeat_timeout"
      , `Float (Time.Span.to_sec t.rpc_heartbeat_timeout) )
    ; ( "rpc_heartbeat_send_every"
      , `Float (Time.Span.to_sec t.rpc_heartbeat_send_every) )
    ; ( "max_zkapp_segment_per_transaction"
      , `Int t.max_zkapp_segment_per_transaction )
    ; ("max_event_elements", `Int t.max_event_elements)
    ; ("max_action_elements", `Int t.max_action_elements)
    ; ("network_id", `String t.network_id)
    ; ( "zkapp_cmd_limit"
      , Option.value_map ~default:`Null ~f:(fun x -> `Int x) t.zkapp_cmd_limit
      )
    ; ("zkapp_cmd_limit_hardcap", `Int t.zkapp_cmd_limit_hardcap)
    ; ("zkapps_disabled", `Bool t.zkapps_disabled)
    ; ("sync_ledger_max_subtree_depth", `Int t.sync_ledger_max_subtree_depth)
    ; ( "sync_ledger_default_subtree_depth"
      , `Int t.sync_ledger_default_subtree_depth )
    ]

(*TODO: Delete this module and read in a value from the environment*)
module Compiled = struct
  let t : t =
    let (inputs : Inputs.t) =
      { curve_size = Node_config.curve_size
      ; default_transaction_fee_string = Node_config.default_transaction_fee
      ; default_snark_worker_fee_string = Node_config.default_snark_worker_fee
      ; minimum_user_command_fee_string = Node_config.minimum_user_command_fee
      ; compaction_interval_ms = Node_config.compaction_interval
      ; block_window_duration_ms = Node_config.block_window_duration
      ; vrf_poll_interval_ms = Node_config.vrf_poll_interval
      ; rpc_handshake_timeout_sec = Node_config.rpc_handshake_timeout_sec
      ; rpc_heartbeat_timeout_sec = Node_config.rpc_heartbeat_timeout_sec
      ; rpc_heartbeat_send_every_sec = Node_config.rpc_heartbeat_send_every_sec
      ; max_zkapp_segment_per_transaction =
          Node_config.max_zkapp_segment_per_transaction
      ; max_event_elements = Node_config.max_event_elements
      ; max_action_elements = Node_config.max_action_elements
      ; network_id = Node_config.network
      ; zkapp_cmd_limit = Node_config.zkapp_cmd_limit
      ; zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap
      ; zkapps_disabled = Node_config.zkapps_disabled
      ; sync_ledger_max_subtree_depth =
          Node_config.sync_ledger_max_subtree_depth
      ; sync_ledger_default_subtree_depth =
          Node_config.sync_ledger_default_subtree_depth
      }
    in
    make inputs
end

module For_unit_tests = struct
  let t : t =
    let inputs : Inputs.t =
      { curve_size = Node_config_for_unit_tests.curve_size
      ; default_transaction_fee_string =
          Node_config_for_unit_tests.default_transaction_fee
      ; default_snark_worker_fee_string =
          Node_config_for_unit_tests.default_snark_worker_fee
      ; minimum_user_command_fee_string =
          Node_config_for_unit_tests.minimum_user_command_fee
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
      ; max_zkapp_segment_per_transaction =
          Node_config_for_unit_tests.max_zkapp_segment_per_transaction
      ; max_event_elements = Node_config_for_unit_tests.max_event_elements
      ; max_action_elements = Node_config_for_unit_tests.max_action_elements
      ; network_id = Node_config_for_unit_tests.network
      ; zkapp_cmd_limit = Node_config_for_unit_tests.zkapp_cmd_limit
      ; zkapp_cmd_limit_hardcap =
          Node_config_for_unit_tests.zkapp_cmd_limit_hardcap
      ; zkapps_disabled = Node_config_for_unit_tests.zkapps_disabled
      ; sync_ledger_max_subtree_depth =
          Node_config_for_unit_tests.sync_ledger_max_subtree_depth
      ; sync_ledger_default_subtree_depth =
          Node_config_for_unit_tests.sync_ledger_default_subtree_depth
      }
    in
    make inputs
end
