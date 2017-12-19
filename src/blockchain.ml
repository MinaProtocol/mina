open Core_kernel
open Async_kernel

module Update = struct
  type t =
    | New_block of Block.t
end

type t =
  { block : Block.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

let accumulate = failwith "TODO"
