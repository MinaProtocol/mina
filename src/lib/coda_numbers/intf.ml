open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib
open Unsigned

module type S = sig
  type t [@@deriving sexp, compare, hash, yojson]

  include Comparable.S with type t := t

  include Hashable.S with type t := t

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, eq, compare, hash, yojson, version]
    end

    module Latest = V1
  end

  val length_in_bits : int

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

  open Snark_params.Tick

  val is_succ_var :
    pred:Unpacked.var -> succ:Unpacked.var -> (Boolean.var, _) Checked.t

  val min_var : Unpacked.var -> Unpacked.var -> (Unpacked.var, _) Checked.t

  val fold : t -> bool Triple.t Fold.t
end

module type UInt32 = sig
  include S with type t = Unsigned_extended.UInt32.t

  val to_uint32 : t -> uint32

  val of_uint32 : uint32 -> t
end

module type UInt64 = sig
  include S with type t = Unsigned_extended.UInt64.t

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t
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
