open Unsigned
open Snark_params.Tick

type t = uint32

let succ = UInt32.succ

let equal a b = UInt32.compare a b = 0

let of_global_slot ~(constants : Constants.t) (s : Global_slot.t) : t =
  UInt32.Infix.(Global_slot.slot_number s / constants.slots_per_sub_window)

let sub_window ~(constants : Constants.t) t =
  UInt32.rem t constants.sub_windows_per_window

let ( >= ) a b = UInt32.compare a b >= 0

let add a b = UInt32.add a b

let sub a b = UInt32.sub a b

let constant a = a

module Checked = struct
  module T = Mina_numbers.Global_slot

  type t = T.Checked.t

  let of_length (x : Mina_numbers.Length.Checked.t) : t =
    T.Checked.Unsafe.of_field (Mina_numbers.Length.Checked.to_field x)

  let of_global_slot ~(constants : Constants.var) (s : Global_slot.Checked.t) :
      t Checked.t =
    let%map q, _ =
      T.Checked.div_mod
        (Global_slot.slot_number s)
        (of_length constants.slots_per_sub_window)
    in
    q

  let sub_window ~(constants : Constants.var) (t : t) :
      Sub_window.Checked.t Checked.t =
    let%map _, shift =
      T.Checked.div_mod t (of_length constants.sub_windows_per_window)
    in
    Sub_window.Checked.Unsafe.of_field (T.Checked.to_field shift)

  let succ (t : t) : t Checked.t = T.Checked.succ t

  let equal = T.Checked.equal

  let constant a =
    T.Checked.Unsafe.of_field @@ Field.Var.constant @@ Field.of_int
    @@ UInt32.to_int a

  let add a (b : Mina_numbers.Length.Checked.t) = T.Checked.add a (of_length b)

  let ( >= ) a b = T.Checked.( >= ) a b
end
