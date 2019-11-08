[%%import
"../../config.mlh"]

open Core

let offset = 20.

let genesis_state_timestamp =
  let zone = Core.Time.Zone.of_utc_offset ~hours:(-8) in
  let fmt = "%Y-%m-%d" in
  let midnight =
    Core.Time.parse (Core.Time.format (Core.Time.now ()) fmt ~zone) ~zone ~fmt
  in
  Coda_base.Block_time.of_time (Time.add midnight (Time.Span.of_hr offset))

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
