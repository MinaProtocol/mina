open Core_kernel
open Async_kernel
open Nanobit_base


module Update : sig
  type t =
    | Change_previous of Blockchain.t
    | Change_body of Block.Body.t
end

module Mined_block_metadata : sig
  type t = {
    hash_attempts: int
  }
end

module type S = sig
  val mine
    : prover:Prover.t
    -> parent_log:Logger.t
    -> initial:Blockchain.t
    -> body:Block.Body.t
    -> Update.t Linear_pipe.Reader.t
    -> (Blockchain.t * Mined_block_metadata.t) Linear_pipe.Reader.t
end

module Cpu : S
