(* FIXME: These should be configurable. *)

let max_zkapp_segment_per_transaction = 16

let max_event_elements = 1024

let max_action_elements = 1024

let zkapp_cmd_limit_hardcap = 128

(* These are fine to be non-configurable *)

let zkapps_disabled = false

let rpc_handshake_timeout_sec = 60.0

let rpc_heartbeat_timeout_sec = 60.0

let rpc_heartbeat_send_every_sec = 10.0 (*same as the default*)
