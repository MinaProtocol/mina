include
  Coda_numbers.Nat.Intf.S_unchecked
  with type t = Coda_numbers.Global_slot.Stable.Latest.t

val ( + ) : t -> int -> t

val create : epoch:Epoch.t -> slot:Slot.t -> t

val of_epoch_and_slot : Epoch.t * Slot.t -> t

val to_uint32 : t -> Unsigned.uint32

val of_uint32 : Unsigned.uint32 -> t

val epoch : t -> Epoch.t

val slot : t -> Slot.t

val to_epoch_and_slot : t -> Epoch.t * Slot.t

module Checked : sig
  include
    Coda_numbers.Nat.Intf.S_checked
    with type unchecked := t
     and type var = Coda_numbers.Global_slot.Checked.var

  open Snark_params.Tick

  val to_epoch_and_slot : t -> (Epoch.Checked.t * Slot.Checked.t, _) Checked.t
end

val typ : (Checked.t, t) Snark_params.Tick.Typ.t
