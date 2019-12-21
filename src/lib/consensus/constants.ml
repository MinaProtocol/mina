[%%import
"/src/config.mlh"]

open Coda_base
open Signed
open Unsigned
module Time = Block_time

let int64_of_uint32 x = x |> UInt32.to_int64 |> Int64.of_int64

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

let sub_windows_per_window = Unsigned.UInt32.of_int c

let slots_per_sub_window = Unsigned.UInt32.of_int k

let slots_per_window =
  Unsigned.UInt32.(mul sub_windows_per_window slots_per_sub_window)

(** Number of slots =24k in ouroboros praos *)
let slots_per_epoch = Unsigned.UInt32.(of_int (3 * c * k))

module Slot = struct
  let duration_ms = Int64.of_int block_window_duration_ms
end

module Epoch = struct
  let size = slots_per_epoch

  (** Amount of time in total for an epoch *)
  let duration =
    Time.Span.of_ms Int64.Infix.(Slot.duration_ms * int64_of_uint32 size)
end

module Checkpoint_window = struct
  let per_year = 12

  let slots_per_year =
    let one_year_ms =
      Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int |> Int.to_int64
    in
    Int64.Infix.(one_year_ms / Slot.duration_ms) |> Int64.to_int

  let size_in_slots =
    assert (slots_per_year mod per_year = 0) ;
    slots_per_year / per_year
end

let epoch_size = UInt32.to_int Epoch.size

let delta_duration =
  Time.Span.of_ms (Int64.of_int (Int64.to_int Slot.duration_ms * delta))
