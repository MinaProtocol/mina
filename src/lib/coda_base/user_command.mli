open Core
open Import
open Snark_params.Tick
module Payload = User_command_payload

type ('payload, 'pk, 'signature) t_ =
  {payload: 'payload; sender: 'pk; signature: 'signature}
[@@deriving bin_io, eq, sexp, hash]

type t = (Payload.t, Public_key.t, Signature.t) t_
[@@deriving bin_io, eq, sexp, hash]

module Stable : sig
  module V1 : sig
    type nonrec ('payload, 'pk, 'signature) t_ =
                                                ('payload, 'pk, 'signature) t_ =
      {payload: 'payload; sender: 'pk; signature: 'signature}
    [@@deriving bin_io, eq, sexp, hash]

    type t =
      (Payload.Stable.V1.t, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, hash]

    val compare : seed:string -> t -> t -> int
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
  type nonrec t = private t [@@deriving sexp, eq, bin_io]

  val compare : seed:string -> t -> t -> int

  val gen :
       keys:Signature_keypair.t array
    -> max_amount:int
    -> max_fee:int
    -> t Quickcheck.Generator.t
end

val sign : Signature_keypair.t -> Payload.t -> With_valid_signature.t

val check : t -> With_valid_signature.t option

val accounts_accessed : t -> Public_key.Compressed.t list
