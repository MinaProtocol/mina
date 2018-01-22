open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

let zero = Snark_params.Main.Field.zero

include Bits.Snarkable.Field(Snark_params.Main)

module Bits = Bits.Make_field(Snark_params.Main.Field)(Snark_params.Main.Bigint)

