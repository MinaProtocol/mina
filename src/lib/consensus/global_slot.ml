open Unsigned
open Core
open Coda_base
open Snark_params.Tick
module T = Coda_numbers.Global_slot

include (T : module type of T with module Checked := T.Checked)

let create ~(epoch : Epoch.t) ~(slot : Slot.t) =
  of_int
    ( Slot.to_int slot
    + (UInt32.to_int Constants.slots_per_epoch * Epoch.to_int epoch) )

let of_epoch_and_slot (epoch, slot) = create ~epoch ~slot

let epoch t = UInt32.Infix.(t / Constants.slots_per_epoch)

let slot t = UInt32.Infix.(t mod Constants.slots_per_epoch)

let to_epoch_and_slot t = (epoch t, slot t)

let ( + ) x n = UInt32.add x (of_int n)

let start_time t =
  let epoch, slot = to_epoch_and_slot t in
  Epoch.slot_start_time epoch slot

let end_time t =
  let epoch, slot = to_epoch_and_slot t in
  Epoch.slot_end_time epoch slot

let time_hum t =
  let epoch, slot = to_epoch_and_slot t in
  sprintf "epoch=%d, slot=%d" (Epoch.to_int epoch) (Slot.to_int slot)

let of_time time =
  let open Or_error.Let_syntax in
  let%map epoch_and_slot = Epoch.epoch_and_slot_of_time time in
  of_epoch_and_slot epoch_and_slot

let of_time_exn time = Or_error.ok_exn (of_time time)

let diff t (other_epoch, other_slot) =
  let open UInt32.Infix in
  let epoch, slot = to_epoch_and_slot t in
  let old_epoch =
    epoch - other_epoch - (UInt32.of_int @@ if other_slot > slot then 1 else 0)
  in
  let old_slot = (slot - other_slot) mod UInt32.of_int Constants.epoch_size in
  of_epoch_and_slot (old_epoch, old_slot)

module Checked = struct
  include T.Checked

  let to_epoch_and_slot (t : t) :
      (Epoch.Checked.t * Slot.Checked.t, _) Checked.t =
    make_checked (fun () ->
        let open Snarky_integer in
        let epoch, slot =
          Integer.div_mod ~m (to_integer t)
            (Integer.constant ~m
               (Bignum_bigint.of_int (UInt32.to_int Constants.slots_per_epoch)))
        in
        ( Epoch.Checked.Unsafe.of_integer epoch
        , Slot.Checked.Unsafe.of_integer slot ) )
end
