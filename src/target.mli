open Core_kernel

type t = private Snark_params.Main.Field.t
[@@deriving bin_io]

val meets_target
  : t
  -> hash:Snark_params.Main.Pedersen.Digest.t
  -> bool

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S
