(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

open Core_kernel

module Inputs = struct
  type t =
    { curve_size : int
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
    ; zkapps_disabled : bool
    }
  [@@deriving yojson]
end

type t =
  { curve_size : int
  ; default_snark_worker_fee : Currency.Fee.t
  ; minimum_user_command_fee : Currency.Fee.t
  ; itn_features : bool
  ; compaction_interval : Time.Span.t option
  ; block_window_duration : Time.Span.t
  ; vrf_poll_interval : Time.Span.t
  ; network_id : string
  ; zkapp_cmd_limit : int option
  ; rpc_handshake_timeout : Time.Span.t
  ; rpc_heartbeat_timeout : Time_ns.Span.t
  ; rpc_heartbeat_send_every : Time_ns.Span.t
  ; zkapps_disabled : bool
  }
[@@deriving sexp_of]

let make (inputs : Inputs.t) =
  { curve_size = inputs.curve_size
  ; default_snark_worker_fee =
      Currency.Fee.of_mina_string_exn inputs.default_snark_worker_fee_string
  ; minimum_user_command_fee =
      Currency.Fee.of_mina_string_exn inputs.minimum_user_command_fee_string
  ; itn_features = inputs.itn_features
  ; compaction_interval =
      Option.map
        ~f:(fun x -> Float.of_int x |> Time.Span.of_ms)
        inputs.compaction_interval_ms
  ; block_window_duration =
      Float.of_int inputs.block_window_duration_ms |> Time.Span.of_ms
  ; vrf_poll_interval =
      Float.of_int inputs.vrf_poll_interval_ms |> Time.Span.of_ms
  ; rpc_handshake_timeout = Time.Span.of_sec inputs.rpc_handshake_timeout_sec
  ; rpc_heartbeat_timeout = Time_ns.Span.of_sec inputs.rpc_heartbeat_timeout_sec
  ; rpc_heartbeat_send_every =
      Time_ns.Span.of_sec inputs.rpc_heartbeat_send_every_sec
  ; network_id = inputs.network_id
  ; zkapp_cmd_limit = inputs.zkapp_cmd_limit
  ; zkapps_disabled = inputs.zkapps_disabled
  }

let to_yojson t =
  `Assoc
    [ ("curve_size", `Int t.curve_size)
    ; ( "default_snark_worker_fee"
      , Currency.Fee.to_yojson t.default_snark_worker_fee )
    ; ( "minimum_user_command_fee"
      , Currency.Fee.to_yojson t.minimum_user_command_fee )
    ; ("itn_features", `Bool t.itn_features)
    ; ( "compaction_interval"
      , Option.value_map ~default:`Null
          ~f:(fun x -> `Float (Time.Span.to_ms x))
          t.compaction_interval )
    ; ("block_window_duration", `Float (Time.Span.to_ms t.block_window_duration))
    ; ("vrf_poll_interval", `Float (Time.Span.to_ms t.vrf_poll_interval))
    ; ( "rpc_handshake_timeout"
      , `Float (Time.Span.to_sec t.rpc_handshake_timeout) )
    ; ( "rpc_heartbeat_timeout"
      , `Float (Time_ns.Span.to_sec t.rpc_heartbeat_timeout) )
    ; ( "rpc_heartbeat_send_every"
      , `Float (Time_ns.Span.to_sec t.rpc_heartbeat_send_every) )
    ; ("network_id", `String t.network_id)
    ; ( "zkapp_cmd_limit"
      , Option.value_map ~default:`Null ~f:(fun x -> `Int x) t.zkapp_cmd_limit
      )
    ; ("zkapps_disabled", `Bool t.zkapps_disabled)
    ]

(*TODO: Delete this module and read in a value from the environment*)
module Compiled = struct
  let t : t =
    let (inputs : Inputs.t) =
      { curve_size = Node_config.curve_size
      ; default_snark_worker_fee_string = Node_config.default_snark_worker_fee
      ; minimum_user_command_fee_string = Node_config.minimum_user_command_fee
      ; itn_features = Node_config.itn_features
      ; compaction_interval_ms = Node_config.compaction_interval
      ; block_window_duration_ms = Node_config.block_window_duration
      ; vrf_poll_interval_ms = Node_config.vrf_poll_interval
      ; network_id = Node_config.network
      ; zkapp_cmd_limit = Node_config.zkapp_cmd_limit
      ; rpc_handshake_timeout_sec = 60.0
      ; rpc_heartbeat_timeout_sec = 60.0
      ; rpc_heartbeat_send_every_sec = 10.0
      ; zkapps_disabled = false
      }
    in
    make inputs
end

module For_unit_tests = struct
  let t : t =
    let inputs : Inputs.t =
      { curve_size = Node_config_for_unit_tests.curve_size
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
      ; network_id = Node_config_for_unit_tests.network
      ; zkapp_cmd_limit = Node_config_for_unit_tests.zkapp_cmd_limit
      ; zkapps_disabled = Node_config_for_unit_tests.zkapps_disabled
      }
    in
    make inputs
end
