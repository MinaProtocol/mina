open Core_kernel

type t = Int64.t
[@@deriving bin_io]

let zero = Int64.zero

include Bits.Snarkable.Int64(Snark_params.Main)

module Bits = Bits.Int64
