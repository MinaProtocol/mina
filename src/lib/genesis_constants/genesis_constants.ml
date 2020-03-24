[%%import
"/src/config.mlh"]

open Core_kernel

(*Constants that can be specified for generating the base proof (that are not required for key-generation) in runtime_genesis_ledger.exe and that can be configured at runtime.
The types are defined such that this module doesn't depend on any of the coda libraries (except blake2) to avoid dependency cycles.
TODO: move key generation to runtime_genesis_ledger.exe to include scan_state constants, consensus constants (c and  block_window_duration) and ledger depth here*)

module T = struct
  (*Protocol constants required for consensus and snarks. Consensus constants is generated using these*)
  module Protocol = struct
    type ('k, 'delta, 'genesis_state_timestamp) _t =
      {k: 'k; delta: 'delta; genesis_state_timestamp: 'genesis_state_timestamp}

    type t = (int, int, Time.t) _t
  end

  type t = {protocol: Protocol.t; txpool_max_size: int}

  let hash (t : t) =
    let str =
      ( List.map
          [t.protocol.k; t.protocol.delta; t.txpool_max_size]
          ~f:Int.to_string
      |> String.concat ~sep:"" )
      ^ Core.Time.to_string t.protocol.genesis_state_timestamp
    in
    Blake2.digest_string str |> Blake2.to_hex
end

include T

[%%inject
"genesis_state_timestamp_string", genesis_state_timestamp]

[%%inject
"k", k]

[%%inject
"delta", delta]

[%%inject
"pool_max_size", pool_max_size]

let genesis_timestamp_of_string str =
  let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  Core.Time.of_string_gen ~if_no_timezone:(`Use_this_one default_timezone) str

let compiled : t =
  { protocol=
      { k
      ; delta
      ; genesis_state_timestamp=
          genesis_timestamp_of_string genesis_state_timestamp_string }
  ; txpool_max_size= pool_max_size }

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
    ; delta: int option
    ; txpool_max_size: int option
    ; genesis_state_timestamp: string option }
  [@@deriving yojson]

  let of_yojson s =
    Result.(
      of_yojson s
      >>= fun t -> validate_time t.genesis_state_timestamp >>= fun _ -> Ok t)
end

module Daemon_config = struct
  type t = {txpool_max_size: int option; genesis_state_timestamp: string option}
  [@@deriving yojson, eq]

  let of_yojson s =
    Result.(
      of_yojson s
      >>= fun t -> validate_time t.genesis_state_timestamp >>= fun _ -> Ok t)
end

let of_config_file ~(default : t) (t : Config_file.t) : t =
  let opt default x = Option.value ~default x in
  let protocol =
    { Protocol.k= opt default.protocol.k t.k
    ; delta= opt default.protocol.delta t.delta
    ; genesis_state_timestamp=
        Option.value_map ~default:default.protocol.genesis_state_timestamp
          t.genesis_state_timestamp ~f:genesis_timestamp_of_string }
  in
  {T.protocol; txpool_max_size= opt default.txpool_max_size t.txpool_max_size}

let to_config_file t : Config_file.t =
  { Config_file.k= Some t.protocol.k
  ; delta= Some t.protocol.delta
  ; txpool_max_size= Some t.txpool_max_size
  ; genesis_state_timestamp=
      Some
        (Core.Time.format t.protocol.genesis_state_timestamp
           "%Y-%m-%d %H:%M:%S%z" ~zone:Core.Time.Zone.utc) }

let of_daemon_config ~(default : t)
    ({txpool_max_size; genesis_state_timestamp} : Daemon_config.t) : t =
  { txpool_max_size=
      Option.value ~default:default.txpool_max_size txpool_max_size
  ; protocol=
      { default.protocol with
        genesis_state_timestamp=
          Option.value_map genesis_state_timestamp
            ~default:default.protocol.genesis_state_timestamp
            ~f:genesis_timestamp_of_string } }

let to_daemon_config (t : t) : Daemon_config.t =
  { txpool_max_size= Some t.txpool_max_size
  ; genesis_state_timestamp=
      Some
        (Core.Time.format t.protocol.genesis_state_timestamp
           "%Y-%m-%d %H:%M:%S%z" ~zone:Core.Time.Zone.utc) }
