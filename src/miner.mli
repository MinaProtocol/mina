open Async_kernel

module Update : sig
  type t =
    | Change_previous of Block.t
    | Change_body of Block.Body.t
end

module type S = sig
  val mine
    : previous:Block.t
    -> body:Block.Body.t
    -> Update.t Pipe.Reader.t
    -> Block.t Pipe.Reader.t
end

module Cpu : S
