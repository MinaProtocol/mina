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

let extensional_block : (Extensional.Block.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_extensional_block" ~version:0
    ~bin_query:Extensional.Block.Stable.Latest.bin_t
    ~bin_response:Unit.Stable.V1.bin_t
