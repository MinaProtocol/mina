open Async_kernel

module type S = sig
  val mine
    :  [ `Change_head of Block.t ] Pipe.Reader.t
    -> Block.t Pipe.Reader.t Deferred.t
end

module Cpu : S
