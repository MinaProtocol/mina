open Core
open Async

module type S = sig
  type blockchain

  type t

  val create : conf_dir:string -> t Deferred.t

  val verify_blockchain : t -> blockchain -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
    t -> Transaction_snark.t -> bool Or_error.t Deferred.t
end

module Make
    (Consensus_mechanism : Consensus.Mechanism.S
                           with type Proof.t = Nanobit_base.Proof.t)
    (Blockchain : Blockchain_snark.Blockchain.S
                  with module Consensus_mechanism = Consensus_mechanism) :
  S with type blockchain := Blockchain.t
