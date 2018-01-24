open Core_kernel
open Snark_params
open Tick

type t = private Field.t
[@@deriving bin_io]

val of_field : Field.t -> t

val meets_target
  : t
  -> hash:Pedersen.Digest.t
  -> bool

include Snarkable.Bits.S
  with type Unpacked.value = t
   and type Packed.value = t
   and type Packed.var = Cvar.t

val strength_unchecked : t -> Strength.t

val strength
  : Packed.var -> (Strength.Packed.var, _) Tick.Checked.t
