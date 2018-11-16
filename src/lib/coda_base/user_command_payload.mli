open Core_kernel
open Signature_lib
open Tuple_lib
open Fold_lib
open Snark_params.Tick

module Body : sig
  type t = Payment of Payment_payload.Stable.V1.t
  [@@deriving bin_io, eq, sexp, hash, yojson]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, eq, sexp, hash, yojson]
    end
  end
end

type t [@@deriving bin_io, eq, sexp, hash, yojson]

val create :
     fee:Currency.Fee.t
  -> nonce:Coda_numbers.Account_nonce.t
  -> memo:User_command_memo.t
  -> body:Body.t
  -> t

type var

val typ : (var, t) Typ.t

val length_in_triples : int

val dummy : t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving bin_io, eq, sexp, hash, yojson]
  end
end

val fold : t -> bool Triple.t Fold.t

val fee : t -> Currency.Fee.t

val nonce : t -> Coda_numbers.Account_nonce.t

val memo : t -> User_command_memo.t

val sender_cost : t -> Currency.Amount.t Or_error.t

val body : t -> Body.t

val accounts_accessed : t -> Public_key.Compressed.t list

module Checked : sig
  val to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val fee : var -> Currency.Fee.var

  val nonce : var -> Coda_numbers.Account_nonce.Unpacked.var

  val payment_payload : var -> Payment_payload.var

  val constant : t -> var
end

val gen : t Quickcheck.Generator.t
