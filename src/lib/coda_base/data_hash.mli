open Core
open Snark_params.Tick
open Snark_bits
open Tuple_lib
open Fold_lib

module type Basic = sig
  (* TODO: Use stable for bin_io *)

  type t = private Pedersen.Digest.t
  [@@deriving bin_io, sexp, eq, compare, hash]

  val gen : t Quickcheck.Generator.t

  val to_bytes : t -> string

  val length_in_triples : int

  val ( = ) : t -> t -> bool

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq, hash]

      include Hashable_binable with type t := t
    end
  end

  type var

  val var_of_hash_unpacked : Pedersen.Checked.Digest.Unpacked.var -> var

  val var_to_hash_packed : var -> Pedersen.Checked.Digest.var

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  val equal_var : var -> var -> (Boolean.var, _) Checked.t

  val var_of_t : t -> var

  include Bits_intf.S with type t := t

  include Hashable.S with type t := t

  val fold : t -> bool Triple.t Fold.t
end

module type Full_size = sig
  include Basic

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val var_of_hash_packed : Pedersen.Checked.Digest.var -> var

  val of_hash : Pedersen.Digest.t -> t
end

module type Small = sig
  include Basic

  val var_of_hash_packed : Pedersen.Checked.Digest.var -> (var, _) Checked.t

  val of_hash : Pedersen.Digest.t -> t Or_error.t
end

module Make_small (M : sig
  val length_in_bits : int
end) : Small

module Make_full_size () : Full_size
