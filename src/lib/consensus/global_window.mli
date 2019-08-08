type t [@@deriving eq]

val succ : t -> t

val of_global_slot : Global_slot.t -> t

module Checked : sig
  open Snark_params.Tick

  type t

  val succ : t -> t

  val equal : t -> t -> (Boolean.var, _) Checked.t

  val of_global_slot : Global_slot.Checked.t -> (t, _) Checked.t
end
