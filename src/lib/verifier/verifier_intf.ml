open Async_kernel
open Core_kernel

module type S = sig
  type t

  val create : unit -> t Deferred.t

  val verify_blockchain_snark :
    t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
       t
    -> Ledger_proof.t
    -> message:Coda_base.Sok_message.t
    -> bool Or_error.t Deferred.t
end
