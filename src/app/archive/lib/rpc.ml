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

(** [Announce_hardfork]: a daemon or an operator tells the archive about a hard
    fork. Typed and versioned: the reply says whether the fork was recorded,
    and why not. *)
let announce_hardfork :
    ( Hardfork_announcement.Query.Stable.V1.t
    , Hardfork_announcement.Reply.Stable.V1.t )
    Rpc.Rpc.t =
  Rpc.Rpc.create ~name:"Announce_hardfork" ~version:1
    ~bin_query:Hardfork_announcement.Query.Stable.V1.bin_t
    ~bin_response:Hardfork_announcement.Reply.Stable.V1.bin_t
