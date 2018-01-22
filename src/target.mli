open Core_kernel

type t = private Snark_params.Main.Field.t
[@@deriving bin_io]

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S
