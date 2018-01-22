open Core_kernel

type t = Int64.t
[@@deriving bin_io]

let zero = Int64.zero

module Snarkable = Bits.Snarkable.Int64

module Bits = Bits.Int64
