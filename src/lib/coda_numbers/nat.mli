open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib

module type S = sig
  type t [@@deriving bin_io, sexp, compare, eq, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]
    end
  end

  val length_in_triples : int

  val gen : t Quickcheck.Generator.t

  val zero : t

  val succ : t -> t

  val of_int : int -> t

  val to_int : t -> int

  (* Someday: I think this only does ones greater than zero, but it doesn't really matter for
    selecting the nonce *)

  val random : unit -> t

  val of_string : string -> t

  val to_string : t -> string

  module Bits : Bits_intf.S with type t := t

  include
    Snark_params.Tick.Snarkable.Bits.Small
    with type Unpacked.value = t
     and type Packed.value = t

  val fold : t -> bool Triple.t Fold.t
end

module type F = functor
  (N :sig
      
      type t [@@deriving bin_io, sexp, compare, hash]

      include Unsigned_extended.S with type t := t

      val random : unit -> t
    end)
  (Bits : Bits_intf.S with type t := N.t)
  (Bits_snarkable :
     Snark_params.Tick.Snarkable.Bits.Small
     with type Packed.value = N.t
      and type Unpacked.value = N.t)
  -> S with type t := N.t and module Bits := Bits

module Make : F

module Make32 () : S with type t = Unsigned_extended.UInt32.t

module Make64 () : S with type t = Unsigned_extended.UInt64.t
