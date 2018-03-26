open Core_kernel
open Async_kernel
open Nanobit_base

module Update : sig
  type t =
    | Change_previous of Blockchain.t
    | Change_body of Block.Body.t
end

module type S = sig
  val mine
    : prover:Prover.t
    -> parent_log:Logger.t
    -> initial:Blockchain.t
    -> transactions:Transaction.t Linear_pipe.Reader.t
    -> ledger:Ledger.t

    -> body:Block.With_transactions.t
    -> Update.t Linear_pipe.Reader.t
    -> Blockchain.t Linear_pipe.Reader.t
end

module Cpu : S
