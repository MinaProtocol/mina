open Core_kernel

let byte_length = 8

type t = Bigstring.t
[@@deriving bin_io]

let max_value =
  Bigstring.init byte_length ~f:(fun _ -> '\255')

module Snarkable (Impl : Camlsnark.Snark_intf.S) =
  Bits.Make_bigstring(Impl)(struct let byte_length = byte_length end)
