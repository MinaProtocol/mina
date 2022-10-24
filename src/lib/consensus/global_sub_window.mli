type t [@@deriving equal]

val succ : t -> t

val of_global_slot : constants:Constants.t -> Global_slot.t -> t

val sub_window : constants:Constants.t -> t -> Sub_window.t

val constant : Unsigned.UInt32.t -> t

val add : t -> t -> t

val sub : t -> t -> Unsigned.UInt32.t

val ( >= ) : t -> t -> bool

module Checked : sig
  open Snark_params.Step

  type t

  val succ : t -> t Checked.t

  val equal : t -> t -> Boolean.var Checked.t

  val constant : Unsigned.UInt32.t -> t

  val add : t -> Mina_numbers.Length.Checked.t -> t Checked.t

  val ( >= ) : t -> t -> Boolean.var Checked.t

  val of_global_slot :
    constants:Constants.var -> Global_slot.Checked.t -> t Checked.t

  val sub_window :
    constants:Constants.var -> t -> Sub_window.Checked.t Checked.t
end
