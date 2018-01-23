open Core_kernel

type t = Snark_params.Main.Field.t
[@@deriving bin_io]

val zero : t

module Bits : Bits_intf.S with type t := t

include Snark_params.Main.Snarkable.Bits.S
  with type Packed.value = t
   and type Unpacked.value = t
   and type Packed.var = Snark_params.Main.Cvar.t
