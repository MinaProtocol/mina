open Unsigned
open Snark_params.Tick

type t = uint32

let succ = UInt32.succ

let equal a b = UInt32.compare a b = 0

let of_global_slot (s : Global_slot.t) : t =
  UInt32.Infix.(Global_slot.to_uint32 s / Constants.slots_per_window)

module Checked = struct
  open Snarky_integer

  type t = field Integer.t

  let of_global_slot (s : Global_slot.Checked.t) : (t, _) Checked.t =
    make_checked (fun () ->
        let open Snarky_integer in
        let q, _ =
          Integer.div_mod ~m
            (Global_slot.Checked.to_integer s)
            (Integer.constant ~m
               (Bignum_bigint.of_int (UInt32.to_int Constants.slots_per_window)))
        in
        q )

  let succ (t : t) : t = Integer.succ ~m t

  let equal a b = make_checked (fun () -> Integer.equal ~m a b)
end
