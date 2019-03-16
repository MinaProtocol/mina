open Core
open Snark_params
open Tick
open Fold_lib
open Tuple_lib
open Import

module Stable : sig
  module V1 : sig
    type t =
      {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
    [@@deriving bin_io, sexp]
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  {fee: Currency.Fee.Stable.V1.t; prover: Public_key.Compressed.Stable.V1.t}
[@@deriving sexp]

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
