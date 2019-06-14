open Core_kernel

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

  val to_bits : t -> bool list
end

val digest_string : string -> Digest.t
