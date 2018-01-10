open Core_kernel
open Async_kernel

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

module Update : sig
  type nonrec t =
    | New_block of t
end

val accumulate
  :  init:t
  -> updates:Update.t Pipe.Reader.t
  -> strongest_block:t Pipe.Writer.t
  -> unit

val valid : t -> bool

val genesis : t
