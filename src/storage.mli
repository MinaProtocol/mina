open Core_kernel
open Async_kernel

module type S = sig
  type location

  val load
    : location -> Block.t option Deferred.t

  val serialize
    : location
    -> [ `Change_head of Block.t ] Pipe.Reader.t
    -> unit
end

module Filesystem : S
