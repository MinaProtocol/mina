open Core
open Snark_params.Tick

type ('pk, 'amount, 'fee, 'nonce) t_ =
  {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce}
[@@deriving bin_io, eq, sexp, hash]

type t =
  ( Public_key.Compressed.t
  , Currency.Amount.t
  , Currency.Fee.t
  , Account_nonce.t )
  t_
[@@deriving bin_io, eq, sexp, hash]

val dummy : t

module Stable : sig
  module V1 : sig
    type nonrec ('pk, 'amount, 'fee, 'nonce) t_ =
                                                  ( 'pk
                                                  , 'amount
                                                  , 'fee
                                                  , 'nonce )
                                                  t_ =
      {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce}
    [@@deriving bin_io, eq, sexp, hash]

    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Currency.Amount.Stable.V1.t
      , Currency.Fee.Stable.V1.t
      , Account_nonce.t )
      t_
    [@@deriving bin_io, eq, sexp, hash]
  end
end

type var =
  ( Public_key.Compressed.var
  , Currency.Amount.var
  , Currency.Fee.var
  , Account_nonce.Unpacked.var )
  t_

val length_in_bits : int

val typ : (var, t) Typ.t

val to_bits : t -> bool list

val fold : t -> init:'acc -> f:('acc -> bool -> 'acc) -> 'acc

val var_to_bits : var -> (Boolean.var list, _) Checked.t
