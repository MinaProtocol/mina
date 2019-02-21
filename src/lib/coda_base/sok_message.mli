open Core
open Snark_params
open Tick
open Fold_lib
open Tuple_lib
open Import

type t = {fee: Currency.Fee.t; prover: Public_key.Compressed.t}
[@@deriving bin_io, sexp]

val create : fee:Currency.Fee.t -> prover:Public_key.Compressed.t -> t

module Digest : sig
  type t [@@deriving sexp, eq]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving sexp, bin_io, hash, compare, eq]
    end

    module Latest = V1
  end

  module Checked : sig
    type t

    val to_triples : t -> Boolean.var Triple.t list
  end

  val fold : t -> bool Triple.t Fold.t

  val typ : (Checked.t, t) Typ.t

  val length_in_triples : int

  val default : t
end

val digest : t -> Digest.t
