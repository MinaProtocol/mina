open Core
open Snark_params.Tick

module type Basic = sig
  type t = private Pedersen.Digest.t [@@deriving sexp, eq]

  val gen : t Quickcheck.Generator.t

  val to_bits : t -> string

  val length_in_bits : int

  val ( = ) : t -> t -> bool

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq]

      include Hashable_binable with type t := t
    end
  end

  type var

  val var_of_hash_unpacked : Pedersen.Digest.Unpacked.var -> var

  val var_to_hash_packed : var -> Pedersen.Digest.Packed.var

  val var_to_bits : var -> (Boolean.var list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  val equal_var : var -> var -> (Boolean.var, _) Checked.t

  include Bits_intf.S with type t := t
end

module type Full_size = sig
  include Basic

  val var_of_hash_packed : Pedersen.Digest.Packed.var -> var

  val of_hash : Pedersen.Digest.t -> t
end

module type Small = sig
  include Basic

  val var_of_hash_packed : Pedersen.Digest.Packed.var -> (var, _) Checked.t

  val of_hash : Pedersen.Digest.t -> t Or_error.t
end

module Make_small (M : sig
  val length_in_bits : int
end) :
  Small

module Make_full_size () : Full_size
