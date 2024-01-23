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
  open Snarky_integer

  type t = field Integer.t

  let of_global_slot ~(constants : Constants.var) (s : Global_slot.Checked.t) :
      (t, _) Checked.t =
    make_checked (fun () ->
        let q, _ =
          Integer.div_mod ~m
            (Mina_numbers.Global_slot.Checked.to_integer
               (Global_slot.slot_number s) )
            (Mina_numbers.Length.Checked.to_integer
               constants.slots_per_sub_window )
        in
        q )

  let sub_window ~(constants : Constants.var) (t : t) :
      (Sub_window.Checked.t, _) Checked.t =
    make_checked (fun () ->
        let _, shift =
          Integer.div_mod ~m t
            (Mina_numbers.Length.Checked.to_integer
               constants.sub_windows_per_window )
        in
        Sub_window.Checked.Unsafe.of_integer shift )

  let succ (t : t) : t = Integer.succ ~m t

  let equal a b = make_checked (fun () -> Integer.equal ~m a b)

  let constant a =
    Integer.constant ~m @@ Bignum_bigint.of_int @@ UInt32.to_int a

  let add a b = Integer.add ~m a (Mina_numbers.Length.Checked.to_integer b)

  let ( >= ) a b = make_checked (fun () -> Integer.gte ~m a b)
end
