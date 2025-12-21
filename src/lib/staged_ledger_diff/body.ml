open Core_kernel

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t = { staged_ledger_diff : Diff.Stable.V2.t }
    [@@deriving equal, fields, sexp]

    let to_latest = Fn.id

    module Creatable = struct
      let id = "block_body"

      type nonrec t = t

      type 'a creator = Diff.Stable.Latest.t -> 'a

      let map_creator c ~f staged_ledger_diff = f (c staged_ledger_diff)

      let create staged_ledger_diff = { staged_ledger_diff }
    end

    include (
      Allocation_functor.Make.Basic
        (Creatable) :
          Allocation_functor.Intf.Output.Basic_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )
  end
end]

module Serializable_type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { staged_ledger_diff : Diff.Serializable_type.Stable.V2.t }

      let to_latest = Fn.id
    end
  end]

  module Creatable = struct
    let id = "block_body"

    type nonrec t = t

    type 'a creator = Diff.Serializable_type.t -> 'a

    let map_creator c ~f staged_ledger_diff = f (c staged_ledger_diff)

    let create staged_ledger_diff = { staged_ledger_diff }
  end

  include (
    Allocation_functor.Make.Basic
      (Creatable) :
        Allocation_functor.Intf.Output.Basic_intf
          with type t := t
           and type 'a creator := 'a Creatable.creator )
end

type t = { staged_ledger_diff : Diff.t } [@@deriving fields]

let create staged_ledger_diff = { staged_ledger_diff }

let to_binio_bigstring b =
  let sz = Stable.V1.bin_size_t b in
  let buf = Bin_prot.Common.create_buf sz in
  ignore (Stable.V1.bin_write_t buf ~pos:0 b : int) ;
  buf

let serialize_with_len_and_tag ~tag b =
  let len = Serializable_type.Stable.V1.bin_size_t b in
  let bs' = Bigstring.create (len + 5) in
  ignore (Serializable_type.Stable.V1.bin_write_t bs' ~pos:5 b : int) ;
  Bigstring.set_uint8_exn ~pos:4 bs' tag ;
  Bigstring.set_uint32_le_exn ~pos:0 bs' (len + 1) ;
  bs'

let compute_reference ~tag =
  Fn.compose snd
  @@ Fn.compose
       (Bitswap_block.blocks_of_data ~max_block_size:262144)
       (serialize_with_len_and_tag ~tag)

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db t =
  { staged_ledger_diff =
      Diff.write_all_proofs_to_disk ~signature_kind ~proof_cache_db
        t.Stable.Latest.staged_ledger_diff
  }

let read_all_proofs_from_disk t =
  { Stable.Latest.staged_ledger_diff =
      Diff.read_all_proofs_from_disk t.staged_ledger_diff
  }

let to_serializable_type t =
  { Serializable_type.staged_ledger_diff =
      Diff.to_serializable_type t.staged_ledger_diff
  }
