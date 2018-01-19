open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

let meets_target t ~hash =
  let module B = Snark_params.Main_curve.Bigint.R in
  B.compare (B.of_field t) (B.of_field hash) < 0
;;

module Snarkable = Bits.Snarkable.Field
