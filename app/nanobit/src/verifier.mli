open Core
open Async

type t

val create : conf_dir:string -> t Deferred.t

val verify_blockchain :
  t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

val verify_transaction_snark :
  t -> Transaction_snark.t -> bool Or_error.t Deferred.t
