open Core_kernel
open Async

let t : (Diff.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_archive_diff" ~version:0 ~bin_query:Diff.bin_t
    ~bin_response:Unit.Stable.V1.bin_t

let precomputed_block :
    ( Mina_transition.External_transition.Precomputed_block.Stable.Latest.t
    , Unit.Stable.V1.t )
    Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_precomputed_block" ~version:0
    ~bin_query:
      Mina_transition.External_transition.Precomputed_block.Stable.Latest.bin_t
    ~bin_response:Unit.Stable.V1.bin_t

(* Extensional.Block.t is not versioned; it doesn't appear in node-to-node RPCs *)
let extensional_block : (Extensional.Block.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_extensional_block" ~version:0
    ~bin_query:Extensional.Block.bin_t ~bin_response:Unit.Stable.V1.bin_t
