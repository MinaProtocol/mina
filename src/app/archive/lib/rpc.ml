open Core_kernel
open Async

let t : (Diff.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_archive_diff" ~version:0 ~bin_query:Diff.bin_t
    ~bin_response:Unit.Stable.V1.bin_t

let precomputed_block :
    (Mina_block.Precomputed.Stable.Latest.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_precomputed_block" ~version:0
    ~bin_query:Mina_block.Precomputed.Stable.Latest.bin_t
    ~bin_response:Unit.Stable.V1.bin_t

(* A precomputed block of any version that [Mina_block.Precomputed.Versioned]
   reads, as its versioned JSON. Blocks of older versions exist only as JSON,
   and converting one to the latest version to send it would change its
   hashes. The response says whether the archive could read the block. *)
let versioned_precomputed_block :
    (string, unit Core_kernel.Or_error.Stable.V2.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_versioned_precomputed_block" ~version:0
    ~bin_query:String.Stable.V1.bin_t
    ~bin_response:[%bin_type_class: unit Core_kernel.Or_error.Stable.V2.t]

let extensional_block : (Extensional.Block.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_extensional_block" ~version:0
    ~bin_query:Extensional.Block.Stable.Latest.bin_t
    ~bin_response:Unit.Stable.V1.bin_t
