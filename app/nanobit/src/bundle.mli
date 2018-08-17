open Core
open Async
open Nanobit_base

module type S0 = sig
  type proof

  type t

  val cancel : t -> unit

  val create :
       conf_dir:string
    -> Ledger.t
    -> Transaction.With_valid_signature.t list
    -> Public_key.Compressed.t
    -> t

  val target_hash : t -> Ledger_hash.t

  val result : t -> proof option Deferred.t
end

module type S = sig
  include S0

  module Sparse_ledger = Nanobit_base.Sparse_ledger
end

module Make
    (Consensus_mechanism : Consensus.Mechanism.S with type Proof.t = Proof.t)
     :
  S with type proof := Transaction_snark.t
