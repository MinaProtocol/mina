open Core_kernel

type t = private Int64.t
[@@deriving bin_io]

val zero : t

module Bits : Bits_intf.S with type t := t

include Snark_params.Main.Snarkable.Bits.S
  with type Unpacked.value = t
   and type Packed.value = t

