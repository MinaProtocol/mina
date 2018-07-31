open Core_kernel
open Snark_bits

module type S = sig
  type t [@@deriving sexp, compare, eq, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]
    end
  end

  val length_in_bits : int

  val gen : t Quickcheck.Generator.t

  val zero : t

  val succ : t -> t

  val of_int : int -> t

  (* Someday: I think this only does ones greater than zero, but it doesn't really matter for
    selecting the nonce *)

  val random : unit -> t

  val of_string : string -> t

  val to_string : t -> string

  module Bits : Bits_intf.S with type t := t

  include Snark_params.Tick.Snarkable.Bits.Small
          with type Unpacked.value = t
           and type Packed.value = t
end

module type F = functor (N :sig
                              
                              type t
                              [@@deriving bin_io, sexp, eq, compare, hash]

                              include Unsigned_extended.S with type t := t

                              val random : unit -> t
end) -> functor (Bits :
  Bits_intf.S with type t := N.t) -> functor (Bits_snarkable :
  Snark_params.Tick.Snarkable.Bits.Small
  with type Packed.value = N.t
   and type Unpacked.value = N.t) -> S
                                     with type t := N.t
                                      and module Bits := Bits

module Make : F

module Make32 () : S with type t = Unsigned_extended.UInt32.t

module Make64 () : S with type t = Unsigned_extended.UInt64.t
