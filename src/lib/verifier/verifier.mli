[%%import "../../config.mlh"]

open Core
open Async

module type S = sig
  type t

  type ledger_proof

  val create : conf_dir:string -> t Deferred.t

  val verify_blockchain_snark :
    t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
       t
    -> ledger_proof
    -> message:Coda_base.Sok_message.t
    -> bool Or_error.t Deferred.t
end

module Prod : S with type ledger_proof = Ledger_proof.Prod.t

module Dummy :
  S with type t = unit and type ledger_proof = Ledger_proof.Debug.t

[%%if proof_level = "full"]

include module type of Prod

[%%else]

include module type of Dummy

[%%endif]
