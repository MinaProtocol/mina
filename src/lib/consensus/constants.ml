[%%import
"/src/config.mlh"]

[%%inject
"genesis_state_timestamp_string", genesis_state_timestamp]

let genesis_state_timestamp =
  let default_timezone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  Core.Time.of_string_gen ~if_no_timezone:(`Use_this_one default_timezone)
    genesis_state_timestamp_string
  |> Coda_base.Block_time.of_time

[%%inject
"k", k]

[%%inject
"coinbase_int", coinbase]

let coinbase = Currency.Amount.of_int coinbase_int

[%%inject
"block_window_duration_ms", block_window_duration]

let block_window_duration =
  Coda_base.Block_time.Span.of_ms (Int64.of_int block_window_duration_ms)

[%%inject
"c", c]

[%%inject
"delta", delta]

(* This is a bit of a hack, see #3232. *)
let inactivity_ms = block_window_duration_ms * 8

(** Number of slots =24k in ouroboros praos *)
let slots_per_epoch = Unsigned.UInt32.of_int (3 * c * k)
