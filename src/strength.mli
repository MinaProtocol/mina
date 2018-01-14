open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

val zero : t

module Bits : Bits_intf.S with type t := t

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S
  with type Packed.value = Impl.Field.t
