open Core_kernel

type t = Bigstring.t
[@@deriving bin_io]

let byte_length = 16

let zero = Bigstring.create byte_length

module Snarkable (Impl : Camlsnark.Snark_intf.S) =
  Bits.Make_bigstring(Impl)(struct let byte_length = byte_length end)
