open Core_kernel
open Snark_params.Tick
open Bitstring_lib
open Fold_lib
open Tuple_lib
open Snark_bits

module Base = struct
  module type S = sig
    type t = private Pedersen.Digest.t
    [@@deriving bin_io, sexp, eq, compare, hash]

    val gen : t Quickcheck.Generator.t

    val of_hash : Pedersen.Digest.t -> t

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

    val create_var :
         digest:Pedersen.Checked.Digest.var
      -> bits:Boolean.var Bitstring.Lsb_first.t option
      -> var

    val var_digest : var -> Pedersen.Checked.Digest.var

    val var_bits : var -> Boolean.var Bitstring.Lsb_first.t option

    val var_of_hash_unpacked : Pedersen.Checked.Digest.Unpacked.var -> var

    val var_to_hash_packed : var -> Pedersen.Checked.Digest.var

    val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

    val unpack : Pedersen.Checked.Digest.var -> (Boolean.var list, _) Checked.t

    val typ : (var, t) Typ.t

    val assert_equal : var -> var -> (unit, _) Checked.t

    val equal_var : var -> var -> (Boolean.var, _) Checked.t

    val var_of_t : t -> var

    val length_in_bits : int

    include Bits_intf.S with type t := t

    include Hashable.S with type t := t

    val fold : t -> bool Triple.t Fold.t
  end
end

module Full_size = struct
  module type S = sig
    include Base.S

    val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

    val var_of_hash_packed : Pedersen.Checked.Digest.var -> var
  end
end

module Small = struct
  module type S = sig
    include Base.S

    val var_of_hash_packed : Pedersen.Checked.Digest.var -> (var, _) Checked.t

    val of_hash : Pedersen.Digest.t -> t Or_error.t
  end
end
