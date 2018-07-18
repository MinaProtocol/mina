open Core_kernel
open Snark_params
open Snark_bits

type t = private Tick.Field.t [@@deriving sexp, bin_io, eq]

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving bin_io, sexp, eq]
  end
end

val bit_length : int

val zero : t

module Bits : Bits_intf.S with type t := t

include Tick.Snarkable.Bits.Faithful
        with type Packed.value = t
         and type Unpacked.value = t
         and type Packed.var = Tick.Field.Checked.t

val field_var_to_unpacked :
  Tick.Field.Checked.t -> (Unpacked.var, _) Tick.Checked.t

val packed_to_number : Packed.var -> (Tick.Number.t, _) Tick.Checked.t

val packed_of_number : Tick.Number.t -> (Packed.var, _) Tick.Checked.t

val of_field : Tick.Field.t -> t

val compare : t -> t -> int

val ( = ) : t -> t -> bool

val ( < ) : t -> t -> bool

val ( > ) : t -> t -> bool

val ( <= ) : t -> t -> bool

val ( >= ) : t -> t -> bool

val of_target_unchecked : Target.t -> t

(* Someday: Have a dual variable type so I don't have to pass both packed and unpacked
   versions. *)

val of_target :
  Target.Packed.var -> Target.Unpacked.var -> (Packed.var, _) Tick.Checked.t

val increase : t -> by:Target.t -> t

val increase_checked :
     Packed.var
  -> by:Target.Packed.var * Target.Unpacked.var
  -> (Packed.var, _) Tick.Checked.t
