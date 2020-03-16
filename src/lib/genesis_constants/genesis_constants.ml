[%%import
"/src/config.mlh"]

open Core_kernel

module T = struct
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
    ; runtime: Runtime_configurable.t }
end

include T

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

let genesis_timestamp_of_string str =
  let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  Core.Time.of_string_gen ~if_no_timezone:(`Use_this_one default_timezone) str

let compiled : t =
  { consensus= {k; c; delta}
  ; scan_state= {work_delay; capacity= scan_state_capacity}
  ; runtime=
      { txpool_max_size= pool_max_size
      ; genesis_state_timestamp=
          genesis_timestamp_of_string genesis_state_timestamp_string
      ; block_window_duration_ms= block_window_duration_ms_compiled } }

let validate_time time_str =
  match
    Result.try_with (fun () ->
        Option.value_map ~default:(Time.now ()) ~f:genesis_timestamp_of_string
          time_str )
  with
  | Ok _time ->
      Ok ()
  | Error _ ->
      Error
        "Invalid timestamp. Please specify timestamp in \"%Y-%m-%d \
         %H:%M:%S%z\". For example, \"2019-01-30 12:00:00-0800\" for \
         UTC-08:00 timezone"

module Config_file = struct
  type t =
    { k: int option
    ; c: int option
    ; delta: int option
    ; scan_state_capacity:
        [`Transaction_capacity_log_2 of int | `Tps_goal_x10 of int] option
    ; scan_state_work_delay: int option
    ; txpool_max_size: int option
    ; genesis_state_timestamp: string option
    ; block_window_duration_ms: int option }
  [@@deriving yojson]

  let of_yojson s =
    Result.(
      of_yojson s
      >>= fun t -> validate_time t.genesis_state_timestamp >>= fun _ -> Ok t)
end

module Daemon_config = struct
  type t =
    { txpool_max_size: int option
    ; genesis_state_timestamp: string option
    ; block_window_duration_ms: int option }
  [@@deriving yojson, eq]

  let of_yojson s =
    Result.(
      of_yojson s
      >>= fun t -> validate_time t.genesis_state_timestamp >>= fun _ -> Ok t)

  let () =
    let time = Time.now () in
    let t =
      { txpool_max_size= Some 1
      ; genesis_state_timestamp= Some "2019-01-30 12:00:00-0800"
      ; block_window_duration_ms= None }
    in
    let y = to_yojson t in
    let t' = of_yojson y |> Result.ok_or_failwith in
    assert (equal t t') ;
    Core.printf
      !"constants: %s\nTime: %s\n%!"
      ( of_yojson y |> Result.ok_or_failwith |> to_yojson
      |> Yojson.Safe.to_string )
      (Time.to_string time)
end

let of_config_file ~(default : t) (t : Config_file.t) : t =
  let opt default x = Option.value ~default x in
  let consensus =
    { Consensus.k= opt default.consensus.k t.k
    ; c= opt default.consensus.c t.c
    ; delta= opt default.consensus.delta t.delta }
  in
  let scan_state =
    { Scan_state.work_delay=
        opt default.scan_state.work_delay t.scan_state_work_delay
    ; capacity= opt default.scan_state.capacity t.scan_state_capacity }
  in
  let runtime =
    { Runtime_configurable.txpool_max_size=
        opt default.runtime.txpool_max_size t.txpool_max_size
    ; genesis_state_timestamp=
        Option.value_map ~default:default.runtime.genesis_state_timestamp
          t.genesis_state_timestamp ~f:genesis_timestamp_of_string
    ; block_window_duration_ms=
        opt default.runtime.block_window_duration_ms t.block_window_duration_ms
    }
  in
  {T.consensus; scan_state; runtime}

let to_config_file t : Config_file.t =
  { Config_file.k= Some t.consensus.k
  ; c= Some t.consensus.c
  ; delta= Some t.consensus.delta
  ; scan_state_capacity= Some t.scan_state.capacity
  ; scan_state_work_delay= Some t.scan_state.work_delay
  ; txpool_max_size= Some t.runtime.txpool_max_size
  ; genesis_state_timestamp=
      Some
        (Core.Time.format t.runtime.genesis_state_timestamp
           "%Y-%m-%d %H:%M:%S%z" ~zone:Core.Time.Zone.utc)
  ; block_window_duration_ms= Some t.runtime.block_window_duration_ms }

let of_daemon_config ~(default : Runtime_configurable.t)
    ({txpool_max_size; genesis_state_timestamp; block_window_duration_ms} :
      Daemon_config.t) : Runtime_configurable.t =
  { Runtime_configurable.txpool_max_size=
      Option.value ~default:default.txpool_max_size txpool_max_size
  ; genesis_state_timestamp=
      Option.value_map genesis_state_timestamp
        ~default:default.genesis_state_timestamp ~f:genesis_timestamp_of_string
  ; block_window_duration_ms=
      Option.value ~default:default.block_window_duration_ms
        block_window_duration_ms }
