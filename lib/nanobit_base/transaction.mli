open Core
open Snark_params.Tick

module Payload : sig
  type ('pk, 'amount, 'fee, 'nonce) t_ =
    {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce}
  [@@deriving bin_io, eq, sexp, compare, hash]

  type t =
    ( Public_key.Compressed.t
    , Currency.Amount.t
    , Currency.Fee.t
    , Account_nonce.t )
    t_
  [@@deriving bin_io, eq, sexp, compare, hash]

  module Stable : sig
    module V1 : sig
      type nonrec ('pk, 'amount, 'fee, 'nonce) t_ =
                                                   ( 'pk
                                                   , 'amount
                                                   , 'fee
                                                   , 'nonce )
                                                   t_ =
        {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce}
      [@@deriving bin_io, eq, sexp, compare, hash]

      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Currency.Fee.Stable.V1.t
        , Account_nonce.t )
        t_
      [@@deriving bin_io, eq, sexp, compare, hash]
    end
  end

  type var =
    ( Public_key.Compressed.var
    , Currency.Amount.var
    , Currency.Fee.var
    , Account_nonce.Unpacked.var )
    t_

  val typ : (var, t) Typ.t

  val to_bits : t -> bool list

  val var_to_bits : var -> (Boolean.var list, _) Checked.t
end

type ('payload, 'pk, 'signature) t_ =
  {payload: 'payload; sender: 'pk; signature: 'signature}
[@@deriving bin_io, eq, sexp, compare, hash]

type t = (Payload.t, Public_key.t, Signature.t) t_
[@@deriving bin_io, eq, sexp, compare, hash]

module Stable : sig
  module V1 : sig
    type nonrec ('payload, 'pk, 'signature) t_ =
                                                ('payload, 'pk, 'signature) t_ =
      {payload: 'payload; sender: 'pk; signature: 'signature}
    [@@deriving bin_io, eq, sexp, compare, hash]

    type t =
      (Payload.Stable.V1.t, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, compare, hash]
  end
end

type var = (Payload.var, Public_key.var, Signature.var) t_

val typ : (var, t) Typ.t

(* Generate a single transaction between
 * $a, b \in keys$
 * for fee $\in [0,max_fee]$
 * and an amount $\in [1,max_amount]$
 *)

val gen :
     keys:Signature_keypair.t array
  -> max_amount:int
  -> max_fee:int
  -> t Quickcheck.Generator.t

module With_valid_signature : sig
  type nonrec t = private t [@@deriving sexp, eq, bin_io, compare]

  val gen :
       keys:Signature_keypair.t array
    -> max_amount:int
    -> max_fee:int
    -> t Quickcheck.Generator.t
end

val sign : Signature_keypair.t -> Payload.t -> With_valid_signature.t

val check : t -> With_valid_signature.t option
