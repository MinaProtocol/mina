open Unsigned
open Snark_params.Tick

type t = uint32

let succ = UInt32.succ

let equal a b = UInt32.compare a b = 0

let of_global_slot (s : Global_slot.t) ~slots_per_sub_window : t =
  UInt32.Infix.(Global_slot.slot_number s / slots_per_sub_window)

let sub_window t ~sub_windows_per_window = UInt32.rem t sub_windows_per_window

let ( >= ) a b = UInt32.compare a b >= 0

let add a b = UInt32.add a b

let sub a b = UInt32.sub a b

let constant a = a

module Checked = struct
  open Snarky_integer

  type t = field Integer.t

  let of_global_slot (s : Global_slot.Checked.t) ~slots_per_sub_window :
      (t, _) Checked.t =
    make_checked (fun () ->
        let q, _ =
          Integer.div_mod ~m
            (Coda_numbers.Global_slot.Checked.to_integer
               (Global_slot.slot_number s))
            (Coda_base.Coda_constants_checked.T.Checked.to_integer
               slots_per_sub_window)
        in
        q )

  let sub_window (t : t) ~sub_windows_per_window :
      (Sub_window.Checked.t, _) Checked.t =
    make_checked (fun () ->
        let _, shift =
          Integer.div_mod ~m t
            (Coda_base.Coda_constants_checked.T.Checked.to_integer
               sub_windows_per_window)
        in
        Sub_window.Checked.Unsafe.of_integer shift )

  let succ (t : t) : t = Integer.succ ~m t

  let equal a b = make_checked (fun () -> Integer.equal ~m a b)

  let constant a =
    Integer.constant ~m @@ Bignum_bigint.of_int @@ UInt32.to_int a

  let add a b = Integer.add ~m a b

  let ( >= ) a b = make_checked (fun () -> Integer.gte ~m a b)
end
