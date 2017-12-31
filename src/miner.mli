open Core_kernel
open Async_kernel

module Update : sig
  type t =
    | Change_previous of Blockchain.t
    | Change_body of Block.Body.t
end

module type S = sig
  val mine
    : previous:Blockchain.t
    -> body:Block.Body.t
    -> Update.t Pipe.Reader.t
    -> Blockchain.t Pipe.Reader.t
end

module Cpu : S
