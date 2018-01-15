open Core_kernel
open Snark_params

type t = Tick.Field.t
[@@deriving bin_io]

val zero : t

module Bits : Bits_intf.S with type t := t

include Tick.Snarkable.Bits.S
  with type Packed.value = t
   and type Unpacked.value = t
   and type Packed.var = Tick.Cvar.t

val compare : t -> t -> int
val (=) : t -> t -> bool
val (<) : t -> t -> bool
val (>) : t -> t -> bool
val (<=) : t -> t -> bool
val (>=) : t -> t -> bool
