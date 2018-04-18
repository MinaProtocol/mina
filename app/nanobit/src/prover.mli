open Core
open Async
open Nanobit_base
open Blockchain_snark

type t

val create : conf_dir:string -> t Deferred.t

val initialized : t -> [`Initialized] Deferred.Or_error.t

val extend_blockchain
  : t
  -> Blockchain.t
  -> Block.t
  -> Blockchain.t Deferred.Or_error.t

val genesis_proof
  : t -> Proof.t Deferred.Or_error.t

val verify_blockchain
  : t -> Blockchain.t -> bool Deferred.Or_error.t

val verify_transaction_snark
  : t -> Transaction_snark.t -> bool Deferred.Or_error.t
