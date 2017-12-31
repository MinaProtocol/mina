open Core_kernel
open Async_kernel

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

type blockchain = t

module Update : sig
  type t =
    | New_block of blockchain
end

val accumulate
  :  init:t option
  -> updates:Update.t Pipe.Reader.t
  -> strongest_block:t Pipe.Writer.t
  -> unit

val valid : t -> bool

val genesis : t
