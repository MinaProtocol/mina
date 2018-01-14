open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

let zero = Snark_params.Main.Field.zero

module Snarkable = Bits.Snarkable.Field

module Bits = Bits.Make_field(Snark_params.Main.Field)(Snark_params.Main.Bigint)

