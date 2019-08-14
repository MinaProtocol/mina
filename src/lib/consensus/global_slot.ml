open Unsigned
open Core
open Snark_params.Tick
open Tuple_lib

include Coda_numbers.Nat.Make32 ()

let create ~(epoch : Epoch.t) ~(slot : Slot.t) =
  of_int
    ( Slot.to_int slot
    + (UInt32.to_int Constants.slots_per_epoch * Epoch.to_int epoch) )

let of_epoch_and_slot (epoch, slot) = create ~epoch ~slot

let epoch t = UInt32.Infix.(t / Constants.slots_per_epoch)

let slot t = UInt32.Infix.(t mod Constants.slots_per_epoch)

let to_epoch_and_slot t = (epoch t, slot t)

module Checked = struct
  (* TODO: It's possible to share this hash computation with
      the hashing of the state. Might be worth doing. *)
  let create ~(epoch : Epoch.Unpacked.var) ~(slot : Slot.Unpacked.var) =
    var_of_field_unsafe
      Field.Var.(
        add
          (Slot.pack_var slot :> t)
          (scale
             (Epoch.pack_var epoch :> t)
             (Field.of_int (UInt32.to_int Constants.slots_per_epoch))))

  open Snarky_taylor

  let to_integer (t : Packed.var) =
    Integer.create
      ~value:(t :> Field.Var.t)
      ~upper_bound:(Bignum_bigint.of_int (1 lsl length_in_bits))

  let to_epoch_and_slot (t : Unpacked.var) :
      Epoch.Unpacked.var * Slot.Unpacked.var =
    let epoch, slot =
      Integer.div_mod ~m
        (Integer.of_bits ~m (Unpacked.var_to_bits t))
        (Integer.constant ~m
           (Bignum_bigint.of_int (UInt32.to_int Constants.slots_per_epoch)))
      |> Double.map ~f:(Integer.to_bits ~m)
    in
    (Epoch.Unpacked.var_of_bits epoch, Slot.Unpacked.var_of_bits slot)
end

let ( + ) x n = UInt32.add x (of_int n)
