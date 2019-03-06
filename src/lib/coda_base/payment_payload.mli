open Core
open Fold_lib
open Tuple_lib
open Snark_params.Tick
open Import

type ('pk, 'amount) t_ = {receiver: 'pk; amount: 'amount}
[@@deriving bin_io, eq, sexp, hash, yojson]

type t = (Public_key.Compressed.t, Currency.Amount.t) t_
[@@deriving bin_io, eq, sexp, hash, yojson]

val dummy : t

val gen : max_amount:Currency.Amount.t -> t Quickcheck.Generator.t

module Stable : sig
  module V1 : sig
    type nonrec ('pk, 'amount) t_ = ('pk, 'amount) t_ =
      {receiver: 'pk; amount: 'amount}
    [@@deriving bin_io, eq, sexp, hash, yojson]

    type t =
      (Public_key.Compressed.Stable.V1.t, Currency.Amount.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, hash, yojson]
  end
end

type var = (Public_key.Compressed.var, Currency.Amount.var) t_

val length_in_triples : int

val typ : (var, t) Typ.t

val to_triples : t -> bool Triple.t list

val fold : t -> bool Triple.t Fold.t

val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

val var_of_t : t -> var
