(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

open Core_kernel

module Inputs = struct
  type t =
    { default_snark_worker_fee_string : string
    ; minimum_user_command_fee_string : string
    ; itn_features : bool
    ; compaction_interval_ms : int option
    ; vrf_poll_interval_ms : int
    ; network_id : string
    ; zkapp_cmd_limit : int option
    ; rpc_handshake_timeout_sec : float
    ; rpc_heartbeat_timeout_sec : float
    ; rpc_heartbeat_send_every_sec : float
    ; zkapps_disabled : bool
    ; sync_ledger_max_subtree_depth : int
    ; sync_ledger_default_subtree_depth : int
    }
  [@@deriving yojson, bin_io_unversioned]
end

type t =
  { default_snark_worker_fee : Currency.Fee.Stable.Latest.t
  ; minimum_user_command_fee : Currency.Fee.Stable.Latest.t
  ; itn_features : bool
  ; compaction_interval : Time.Span.t option
  ; vrf_poll_interval : Time.Span.t
  ; network_id : string
  ; zkapp_cmd_limit : int option
  ; rpc_handshake_timeout : Time.Span.t
  ; rpc_heartbeat_timeout : Time_ns.Span.t
  ; rpc_heartbeat_send_every : Time_ns.Span.t
  ; zkapps_disabled : bool
  ; sync_ledger_max_subtree_depth : int
  ; sync_ledger_default_subtree_depth : int
  }
[@@deriving sexp_of, bin_io_unversioned]

let make (inputs : Inputs.t) =
  { default_snark_worker_fee =
      Currency.Fee.of_mina_string_exn inputs.default_snark_worker_fee_string
  ; minimum_user_command_fee =
      Currency.Fee.of_mina_string_exn inputs.minimum_user_command_fee_string
  ; itn_features = inputs.itn_features
  ; compaction_interval =
      Option.map
        ~f:(fun x -> Float.of_int x |> Time.Span.of_ms)
        inputs.compaction_interval_ms
  ; vrf_poll_interval =
      Float.of_int inputs.vrf_poll_interval_ms |> Time.Span.of_ms
  ; rpc_handshake_timeout = Time.Span.of_sec inputs.rpc_handshake_timeout_sec
  ; rpc_heartbeat_timeout = Time_ns.Span.of_sec inputs.rpc_heartbeat_timeout_sec
  ; rpc_heartbeat_send_every =
      Time_ns.Span.of_sec inputs.rpc_heartbeat_send_every_sec
  ; network_id = inputs.network_id
  ; zkapp_cmd_limit = inputs.zkapp_cmd_limit
  ; zkapps_disabled = inputs.zkapps_disabled
  ; sync_ledger_max_subtree_depth = inputs.sync_ledger_max_subtree_depth
  ; sync_ledger_default_subtree_depth = inputs.sync_ledger_default_subtree_depth
  }

let to_yojson t =
  `Assoc
    [ ( "default_snark_worker_fee"
      , Currency.Fee.to_yojson t.default_snark_worker_fee )
    ; ( "minimum_user_command_fee"
      , Currency.Fee.to_yojson t.minimum_user_command_fee )
    ; ("itn_features", `Bool t.itn_features)
    ; ( "compaction_interval"
      , Option.value_map ~default:`Null
          ~f:(fun x -> `Float (Time.Span.to_ms x))
          t.compaction_interval )
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
    ; ("sync_ledger_max_subtree_depth", `Int t.sync_ledger_max_subtree_depth)
    ; ( "sync_ledger_default_subtree_depth"
      , `Int t.sync_ledger_default_subtree_depth )
    ]

(*TODO: Delete this module and read in a value from the environment*)
module Compiled = struct
  let t : t =
    let (inputs : Inputs.t) =
      { default_snark_worker_fee_string = Node_config.default_snark_worker_fee
      ; minimum_user_command_fee_string = Node_config.minimum_user_command_fee
      ; itn_features = Node_config.itn_features
      ; compaction_interval_ms = Node_config.compaction_interval
      ; vrf_poll_interval_ms = Node_config.vrf_poll_interval
      ; network_id = Node_config.network
      ; zkapp_cmd_limit = Node_config.zkapp_cmd_limit
      ; rpc_handshake_timeout_sec = 60.0
      ; rpc_heartbeat_timeout_sec = 60.0
      ; rpc_heartbeat_send_every_sec = 10.0
      ; zkapps_disabled = false
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
      { default_snark_worker_fee_string =
          Node_config_for_unit_tests.default_snark_worker_fee
      ; minimum_user_command_fee_string =
          Node_config_for_unit_tests.minimum_user_command_fee
      ; itn_features = Node_config_for_unit_tests.itn_features
      ; compaction_interval_ms = Node_config_for_unit_tests.compaction_interval
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
      ; sync_ledger_max_subtree_depth =
          Node_config_for_unit_tests.sync_ledger_max_subtree_depth
      ; sync_ledger_default_subtree_depth =
          Node_config_for_unit_tests.sync_ledger_default_subtree_depth
      }
    in
    make inputs
end
