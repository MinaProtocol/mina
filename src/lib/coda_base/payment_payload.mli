open Core
open Fold_lib
open Tuple_lib
open Snark_params.Tick
open Import

module Poly : sig
  module Stable : sig
    module V1 : sig
      type nonrec ('pk, 'amount) t = {receiver: 'pk; amount: 'amount}
      [@@deriving bin_io, eq, sexp, hash, yojson, version]
    end

    module Latest = V1
  end
end

module Stable : sig
  module V1 : sig
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Currency.Amount.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving bin_io, eq, sexp, hash, yojson, version]
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

val dummy : t

val gen : max_amount:Currency.Amount.t -> t Quickcheck.Generator.t

type var =
  (Public_key.Compressed.var, Currency.Amount.var) Poly.Stable.Latest.t

val length_in_triples : int

val typ : (var, t) Typ.t

val to_triples : t -> bool Triple.t list

val fold : t -> bool Triple.t Fold.t

val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

val var_of_t : t -> var
