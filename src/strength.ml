open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

let zero = Snark_params.Main.Field.zero

(* TODO: Should assert that the field in the input impl is at
   least as large as Main.Field *)
module Snarkable = Bits.Snarkable.Field

module Bits = Bits.Make_field(Snark_params.Main.Field)(Snark_params.Main.Bigint)

