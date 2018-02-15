open Core_kernel
open Snark_params
open Tick

type t = private Field.t
[@@deriving sexp]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp]
  end
end

val bit_length : int

val max : t

val of_field : Field.t -> t

val meets_target_unchecked
  : t
  -> hash:Pedersen.Digest.t
  -> bool

include Snarkable.Bits.S
  with type Unpacked.value = t
   and type Packed.value = t
   and type Packed.var = private Cvar.t

val passes : Packed.var -> Pedersen.Digest.Packed.var -> (Boolean.var, _) Tick.Checked.t

val pack : Unpacked.var -> Packed.var

val var_to_unpacked : Cvar.t -> (Unpacked.var, _) Tick.Checked.t

val constant : Packed.value -> Packed.var

val strength_unchecked : t -> Strength.t

(* Someday: Have a dual variable type so I don't have to pass both packed and unpacked
   versions. *)
val strength
  : Packed.var
  -> Unpacked.var
  -> (Strength.Packed.var, _) Tick.Checked.t

val to_bigint : t -> Bignum.Bigint.t
val of_bigint : Bignum.Bigint.t -> t
