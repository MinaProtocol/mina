[%%import
"../../config.mlh"]

open Async_kernel
open Core_kernel
open Blockchain_snark
open Coda_base

module type S = sig
  type t

  type ledger_proof

  val create : conf_dir:string -> t Deferred.t

  val verify_blockchain_snark : t -> Blockchain.t -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
    t -> ledger_proof -> message:Sok_message.t -> bool Or_error.t Deferred.t
end

module Prod = Prod
module Dummy = Dummy

[%%if
proof_level = "full"]

include Prod

[%%else]

include Dummy

[%%endif]
