open Core_kernel
open Async_kernel

module Update : sig
  type t =
    | New_block of Block.t
end

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

val accumulate
  :  init:Block.t
  -> updates:Update.t Pipe.Reader.t
  -> strongest_block:Block.t Pipe.Writer.t
  -> unit
