open Core
open Async

module type S = sig
  type t

  val create : conf_dir:string -> logger:Logger.t -> t Deferred.t

  val verify_blockchain : t -> Blockchain_snark.Blockchain.t -> bool Deferred.t

  val verify_transaction_snark :
       t
    -> Transaction_snark.t
    -> message:Coda_base.Sok_message.t
    -> bool Deferred.t
end

include S
