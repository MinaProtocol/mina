open Core_kernel
open Crypto_params

module Digest : sig
  type t = private string [@@deriving sexp, compare, hash, yojson]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, compare, hash, yojson, version {numbered}]

      include Comparable.S with type t := t
    end

    module Latest = V1
  end

  include Comparable.S with type t := t

  val gen : t Quickcheck.Generator.t

  val fold_bits : t -> bool Fold_lib.Fold.t

  val fold : t -> bool Tuple_lib.Triple.t Fold_lib.Fold.t

  val length_in_bits : int

  val length_in_bytes : int

  val length_in_triples : int

  val of_string : string -> t

  val to_string : t -> string

  val to_bits : t -> bool array

  module Checked : sig
    type unchecked = t

    type t = private Tick0.Boolean.var array

    val to_bits : t -> Tick0.Boolean.var array

    val to_triples : t -> Tick0.Boolean.var Tuple_lib.Triple.t list

    val constant : unchecked -> t
  end

  val typ : (Checked.t, t) Tick0.Typ.t
end

val digest_string : string -> Digest.t

val digest_field : Tick0.Field.t -> Digest.t

module Checked : sig
  open Tick0

  val digest_bits : Boolean.var list -> (Digest.Checked.t, _) Checked.t

  val digest_field : Field.Var.t -> (Digest.Checked.t, _) Checked.t
end
