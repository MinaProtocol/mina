[%%import
"/src/config.mlh"]

open Core_kernel

module Consensus = struct
  type t = {k: int; c: int; delta: int}
end

module Scan_state = struct
  type t =
    { capacity: [`Transaction_capacity_log_2 of int | `Tps_goal_x10 of int]
    ; work_delay: int }
end

module Runtime_configurable = struct
  type t =
    { txpool_max_size: int
    ; genesis_state_timestamp: Time.t
    ; block_window_duration_ms: int }
end

type t =
  { consensus: Consensus.t
  ; scan_state: Scan_state.t
  ; runtime: Runtime_configurable.t
        (*TODO: include coinbase, account creation fee?*) }

[%%inject
"block_window_duration_ms_compiled", block_window_duration]

[%%inject
"genesis_state_timestamp_string", genesis_state_timestamp]

[%%inject
"k", k]

[%%inject
"c", c]

[%%inject
"delta", delta]

[%%inject
"work_delay", scan_state_work_delay]

[%%if
scan_state_with_tps_goal]

[%%inject
"tps_goal_x10", scan_state_tps_goal_x10]

let scan_state_capacity = `Tps_goal_x10 tps_goal_x10

[%%else]

[%%inject
"transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

let scan_state_capacity =
  `Transaction_capacity_log_2 transaction_capacity_log_2

[%%endif]

[%%inject
"pool_max_size", pool_max_size]

let genesis_state_timestamp_compiled =
  let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  Core.Time.of_string_gen ~if_no_timezone:(`Use_this_one default_timezone)
    genesis_state_timestamp_string

let compiled : t =
  { consensus= {k; c; delta}
  ; scan_state= {work_delay; capacity= scan_state_capacity}
  ; runtime=
      { txpool_max_size=
          pool_max_size (*The following two needs to be generated here*)
      ; genesis_state_timestamp= genesis_state_timestamp_compiled
      ; block_window_duration_ms= block_window_duration_ms_compiled } }
