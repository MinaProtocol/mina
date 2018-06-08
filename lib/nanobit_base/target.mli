open Core_kernel
open Snark_params
open Tick

type t = private Field.t
[@@deriving sexp, bin_io, eq]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp, eq]
  end
end

val bit_length : int

val max : t

val of_field : Field.t -> t

module Bits : Bits_intf.S with type t := t

include Snarkable.Bits.Faithful
  with type Unpacked.value = t
   and type Packed.value = t
   and type Packed.var = private Cvar.t

val var_to_unpacked : Cvar.t -> (Unpacked.var, _) Tick.Checked.t

val constant : Packed.value -> Packed.var

val to_bigint : t -> Snarky.Bignum_bigint.t
val of_bigint : Snarky.Bignum_bigint.t -> t
