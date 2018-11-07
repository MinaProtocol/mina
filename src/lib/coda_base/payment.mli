open Core
open Import
open Snark_params.Tick
module Payload = Payment_payload

type t = Payload.t Signed_payload.t

module With_valid_signature : sig
  type nonrec t = private t [@@deriving sexp, eq, bin_io]

  val compare : seed:string -> t -> t -> int

  val gen :
       keys:Signature_keypair.t array
    -> max_amount:int
    -> max_fee:int
    -> t Quickcheck.Generator.t
end

include
  Signed_payload.S
  with module Payload := Payload
   and type t := t
   and module With_valid_signature := With_valid_signature

module Stable : sig
  module V1 : sig
    type t = Payload.Stable.V1.t Signed_payload.Stable.V1.t
    [@@deriving bin_io, eq, sexp, hash]

    val compare : seed:string -> t -> t -> int
  end
end

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

val public_keys : t -> Public_key.Compressed.t list
