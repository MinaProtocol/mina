open Core
open Coda_base
open Signed
open Unsigned
open Num_util

include Coda_numbers.Nat.Make32 ()

module Time = Block_time

let of_time_exn t : t =
  let coda_constants = Lazy.force !Coda_constants.t in
  if Time.(t < of_time coda_constants.genesis_state_timestamp) then
    raise
      (Invalid_argument
         "Epoch.of_time: time is earlier than genesis block timestamp") ;
  let time_since_genesis =
    Time.diff t (Time.of_time coda_constants.genesis_state_timestamp)
  in
  uint32_of_int64
    Int64.Infix.(
      Time.Span.to_ms time_since_genesis
      / Time.Span.(
          to_ms @@ of_time_span coda_constants.consensus.epoch_duration))

let start_time (epoch : t) =
  let coda_constants = Lazy.force !Coda_constants.t in
  let ms =
    let open Int64.Infix in
    Block_time.Span.to_ms
      Block_time.(
        to_span_since_epoch @@ of_time coda_constants.genesis_state_timestamp)
    + int64_of_uint32 epoch
      * Block_time.Span.(
          to_ms @@ of_time_span coda_constants.consensus.epoch_duration)
  in
  Block_time.of_span_since_epoch (Block_time.Span.of_ms ms)

let end_time (epoch : t) =
  let coda_constants = Lazy.force !Coda_constants.t in
  Time.add (start_time epoch)
    (Time.Span.of_time_span coda_constants.consensus.epoch_duration)

let slot_start_time (epoch : t) (slot : Slot.t) =
  let coda_constants = Lazy.force !Coda_constants.t in
  Block_time.add (start_time epoch)
    (Block_time.Span.of_ms
       Int64.Infix.(
         int64_of_uint32 slot
         * Int64.of_int coda_constants.consensus.slot_duration_ms))

let slot_end_time (epoch : t) (slot : Slot.t) =
  let coda_constants = Lazy.force !Coda_constants.t in
  Time.add
    (slot_start_time epoch slot)
    ( Int64.of_int coda_constants.consensus.block_window_duration_ms
    |> Time.Span.of_ms )

let epoch_and_slot_of_time_exn tm : t * Slot.t =
  let coda_constants = Lazy.force !Coda_constants.t in
  let epoch = of_time_exn tm in
  let time_since_epoch = Block_time.diff tm (start_time epoch) in
  let slot =
    uint32_of_int64
    @@ Int64.Infix.(
         Time.Span.to_ms time_since_epoch
         / Int64.of_int coda_constants.consensus.slot_duration_ms)
  in
  (epoch, slot)

let diff_in_slots ((epoch, slot) : t * Slot.t) ((epoch', slot') : t * Slot.t) :
    int64 =
  let coda_constants = Lazy.force !Coda_constants.t in
  let ( < ) x y = Pervasives.(Int64.compare x y < 0) in
  let ( > ) x y = Pervasives.(Int64.compare x y > 0) in
  let open Int64.Infix in
  let of_uint32 = UInt32.to_int64 in
  let epoch, slot = (of_uint32 epoch, of_uint32 slot) in
  let epoch', slot' = (of_uint32 epoch', of_uint32 slot') in
  let epoch_size = of_uint32 coda_constants.consensus.epoch_size in
  let epoch_diff = epoch - epoch' in
  if epoch_diff > 0L then
    ((epoch_diff - 1L) * epoch_size) + slot + (epoch_size - slot')
  else if epoch_diff < 0L then
    ((epoch_diff + 1L) * epoch_size) - (epoch_size - slot) - slot'
  else slot - slot'

let%test_unit "test diff_in_slots" =
  let coda_constants = Lazy.force !Coda_constants.t in
  let open Int64.Infix in
  let ( !^ ) = UInt32.of_int in
  let ( !@ ) = Fn.compose ( !^ ) Int64.to_int in
  let epoch_size = UInt32.to_int64 coda_constants.consensus.epoch_size in
  [%test_eq: int64] (diff_in_slots (!^0, !^5) (!^0, !^0)) 5L ;
  [%test_eq: int64] (diff_in_slots (!^3, !^23) (!^3, !^20)) 3L ;
  [%test_eq: int64] (diff_in_slots (!^4, !^4) (!^3, !^0)) (epoch_size + 4L) ;
  [%test_eq: int64] (diff_in_slots (!^5, !^2) (!^4, !@(epoch_size - 3L))) 5L ;
  [%test_eq: int64]
    (diff_in_slots (!^6, !^42) (!^2, !^16))
    ((epoch_size * 3L) + 42L + (epoch_size - 16L)) ;
  [%test_eq: int64]
    (diff_in_slots (!^2, !@(epoch_size - 1L)) (!^3, !^4))
    (0L - 5L) ;
  [%test_eq: int64]
    (diff_in_slots (!^1, !^3) (!^7, !^27))
    (0L - ((epoch_size * 5L) + (epoch_size - 3L) + 27L))

let incr ((epoch, slot) : t * Slot.t) =
  let open UInt32 in
  let coda_constants = Lazy.force !Coda_constants.t in
  if Slot.equal slot (sub coda_constants.consensus.epoch_size one) then
    (add epoch one, zero)
  else (epoch, add slot one)
