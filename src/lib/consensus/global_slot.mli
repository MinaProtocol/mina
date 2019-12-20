open Coda_base

include
  Coda_numbers.Nat.Intf.S_unchecked
  with type t = Coda_numbers.Global_slot.Stable.Latest.t

[%%versioned:
module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp, eq, compare, hash, yojson]
  end
end]

val ( + ) : t -> int -> t

val create : epoch:Epoch.t -> slot:Slot.t -> t

val of_epoch_and_slot : Epoch.t * Slot.t -> t

val to_uint32 : t -> Unsigned.uint32

val of_uint32 : Unsigned.uint32 -> t

val epoch : t -> Epoch.t

val slot : t -> Slot.t

val start_time : t -> Block_time.t

val end_time : t -> Block_time.t

val time_hum : t -> string

val to_epoch_and_slot : t -> Epoch.t * Slot.t

val of_time_exn : Block_time.t -> t

val diff : t -> Epoch.t * Slot.t -> t

module Checked : sig
  include
    Coda_numbers.Nat.Intf.S_checked
    with type unchecked := t
     and type var = Coda_numbers.Global_slot.Checked.var

  open Snark_params.Tick

  val to_epoch_and_slot : t -> (Epoch.Checked.t * Slot.Checked.t, _) Checked.t
end

val typ : (Checked.t, t) Snark_params.Tick.Typ.t
