open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

module Snarkable = Bits.Snarkable.Field
