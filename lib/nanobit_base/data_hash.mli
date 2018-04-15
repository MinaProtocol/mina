open Core
open Snark_params.Tick

module type S = sig
  type t = private Pedersen.Digest.t
  [@@deriving sexp, eq]

  val bit_length : int

  val (=) : t -> t -> bool

  val of_hash : Pedersen.Digest.t -> t

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, eq]
    end
  end

  type var

  val var_of_hash_unpacked : Pedersen.Digest.Unpacked.var -> var
  val var_of_hash_packed : Pedersen.Digest.Packed.var -> var

  val var_to_hash_packed : var -> Pedersen.Digest.Packed.var

  val var_to_bits : var -> (Boolean.var list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  include Bits_intf.S with type t := t
end

module Make() : S
