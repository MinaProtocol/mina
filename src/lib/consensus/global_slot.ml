open Unsigned
open Core
open Coda_base
open Snark_params.Tick

module T = Coda_numbers.Nat.Make32 ()

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
  Block_time.add Constants.genesis_state_timestamp
    Block_time.Span.(
      Constants.block_window_duration * of_ms (UInt32.to_int64 t))

let end_time t = start_time (t + 1)

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
