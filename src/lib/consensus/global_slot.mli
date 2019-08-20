include Coda_numbers.Nat.S

val ( + ) : t -> int -> t

val create : epoch:Epoch.t -> slot:Slot.t -> t

val of_epoch_and_slot : Epoch.t * Slot.t -> t

val epoch : t -> Epoch.t

val slot : t -> Slot.t

val to_epoch_and_slot : t -> Epoch.t * Slot.t

module Checked : sig
  val create : epoch:Epoch.Unpacked.var -> slot:Slot.Unpacked.var -> Packed.var

  val to_integer :
    Packed.var -> Snark_params.Tick.field Snarky_taylor.Integer.t

  val to_epoch_and_slot :
    Unpacked.var -> Epoch.Unpacked.var * Slot.Unpacked.var
end
