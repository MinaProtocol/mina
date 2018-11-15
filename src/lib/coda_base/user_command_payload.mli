open Core_kernel
open Signature_lib
open Tuple_lib
open Fold_lib
open Snark_params.Tick

module Body : sig
  type t =
    | Payment of Payment_payload.Stable.V1.t
    | Stake_delegation of Stake_delegation.Stable.V1.t
  [@@deriving bin_io, eq, sexp, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, eq, sexp, hash]
    end
  end
end

module Common : sig
  type ('fee, 'nonce, 'memo) t_ = {fee: 'fee; nonce: 'nonce; memo: 'memo}
  [@@deriving bin_io, eq, sexp, hash]

  type t =
    ( Currency.Fee.Stable.V1.t
    , Coda_numbers.Account_nonce.Stable.V1.t
    , User_command_memo.t )
    t_
  [@@deriving bin_io, eq, sexp, hash]

  val gen : t Quickcheck.Generator.t

  type var =
    ( Currency.Fee.var
    , Coda_numbers.Account_nonce.Unpacked.var
    , User_command_memo.var )
    t_

  val typ : (var, t) Typ.t

  val fold : t -> bool Triple.t Fold.t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, eq, sexp, hash]
    end
  end

  module Checked : sig
    val to_triples : var -> Boolean.var Triple.t list

    val constant : t -> var
  end
end

type ('common, 'body) t_ = {common: 'common; body: 'body}
[@@deriving bin_io, eq, sexp, hash]

type t = (Common.t, Body.t) t_ [@@deriving bin_io, eq, sexp, hash]

val create :
     fee:Currency.Fee.t
  -> nonce:Coda_numbers.Account_nonce.t
  -> memo:User_command_memo.t
  -> body:Body.t
  -> t

val length_in_triples : int

val dummy : t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving bin_io, eq, sexp, hash]
  end
end

val fold : t -> bool Triple.t Fold.t

val fee : t -> Currency.Fee.t

val nonce : t -> Coda_numbers.Account_nonce.t

val memo : t -> User_command_memo.t

val body : t -> Body.t

val accounts_accessed : t -> Public_key.Compressed.t list

val gen : t Quickcheck.Generator.t
