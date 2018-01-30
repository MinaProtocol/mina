open Core_kernel
open Nanobit_base
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

(* Someday: Have a dual variable type so I don't have to pass both packed and unpacked
   versions. *)
val strength
  : Packed.var
  -> Unpacked.var
  -> (Strength.Packed.var, _) Tick.Checked.t
