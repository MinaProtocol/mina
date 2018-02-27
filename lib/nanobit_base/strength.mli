open Core_kernel
open Snark_params

type t = Tick.Field.t
[@@deriving sexp]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp]
  end
end

val zero : t

module Bits : Bits_intf.S with type t := t

include Tick.Snarkable.Bits.Faithful
  with type Packed.value = t
   and type Unpacked.value = t
   and type Packed.var = Tick.Cvar.t

val field_var_to_unpacked : Tick.Cvar.t -> (Unpacked.var, _) Tick.Checked.t

val compare : t -> t -> int
val (=) : t -> t -> bool
val (<) : t -> t -> bool
val (>) : t -> t -> bool
val (<=) : t -> t -> bool
val (>=) : t -> t -> bool
