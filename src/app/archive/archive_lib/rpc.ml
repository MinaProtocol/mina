open Core_kernel
open Async

let t : (Diff.Stable.Latest.t, Unit.Stable.V1.t) Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Send_archive_diff" ~version:0
    ~bin_query:Diff.Stable.Latest.bin_t ~bin_response:Unit.Stable.V1.bin_t
