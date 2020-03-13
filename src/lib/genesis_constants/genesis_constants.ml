open Coda_base

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
    ; genesis_state_timestamp: Block_time.t
    ; block_window_duration_ms: int }
end

type t =
  { consensus: Consensus.t
  ; scan_state: Scan_state.t
  ; ledger_depth: int
  ; curve_size: int
  ; runtime: Runtime_configurable.t
        (*TODO: include coinbase, account creation fee?*) }
