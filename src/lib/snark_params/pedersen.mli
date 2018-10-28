open Core_kernel
open Snark_bits
open Fold_lib
open Tuple_lib

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io, sexp, eq, hash, compare]

    val size_in_bits : int

    val fold : t -> bool Triple.t Fold.t

    val ( = ) : t -> t -> bool

    module Bits : Bits_intf.S with type t := t

    module Snarkable (Impl : Snark_intf.S) :
      Impl.Snarkable.Bits.Lossy
      with type Packed.var = Impl.Field.Checked.t
       and type Packed.value = Impl.Field.t
       and type Unpacked.value = Impl.Field.t
  end

  module Params : sig
    type t = curve Quadruple.t array
  end

  module State : sig
    type t = {triples_consumed: int; acc: curve; params: Params.t}

    val create : ?triples_consumed:int -> ?init:curve -> Params.t -> t

    val update_fold : t -> bool Triple.t Fold.t -> t

    val digest : t -> Digest.t

    val salt : Params.t -> string -> t
  end

  val hash_fold : State.t -> bool Triple.t Fold.t -> State.t

  val digest_fold : State.t -> bool Triple.t Fold.t -> Digest.t
end

module Make (Field : sig
  type t [@@deriving sexp, bin_io, compare, hash, eq]

  include Snarky.Field_intf.S with type t := t
end)
(Bigint : Snarky.Bigint_intf.Extended with type field := Field.t) (Curve : sig
    type t

    val to_coords : t -> Field.t * Field.t

    val zero : t

    val add : t -> t -> t

    val negate : t -> t
end) : S with type curve := Curve.t and type Digest.t = Field.t
