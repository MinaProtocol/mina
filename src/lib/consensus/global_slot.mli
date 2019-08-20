include Coda_numbers.Nat.S_unchecked

val ( + ) : t -> int -> t

val create : epoch:Epoch.t -> slot:Slot.t -> t

val of_epoch_and_slot : Epoch.t * Slot.t -> t

val epoch : t -> Epoch.t

val slot : t -> Slot.t

val to_epoch_and_slot : t -> Epoch.t * Slot.t

module Checked : sig
  include Coda_numbers.Nat.S_checked with type unchecked := t

  open Snark_params.Tick

  val to_epoch_and_slot : t -> (Epoch.Checked.t * Slot.Checked.t, _) Checked.t
end
