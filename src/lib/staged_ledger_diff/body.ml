open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { staged_ledger_diff : Diff.Stable.V2.t }
    [@@deriving compare, sexp, fields]

    let to_latest = Fn.id

    let to_yojson _ = `String "<opaque>"

    module Creatable = struct
      let id = "block_body"

      type nonrec t = t

      let sexp_of_t = sexp_of_t

      let t_of_sexp = t_of_sexp

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

    include (
      Allocation_functor.Make.Sexp
        (Creatable) :
          Allocation_functor.Intf.Output.Sexp_intf
            with type t := t
             and type 'a creator := 'a Creatable.creator )
  end
end]

type t = Stable.Latest.t

[%%define_locally
Stable.Latest.
  (create, to_yojson, sexp_of_t, t_of_sexp, compare, staged_ledger_diff)]

let compute_reference b =
  let sz = Stable.V1.bin_size_t b in
  let buf = Bin_prot.Common.create_buf sz in
  ignore (Stable.V1.bin_write_t buf ~pos:0 b : int) ;
  snd @@ Bitswap_block.blocks_of_data ~max_block_size:1024 buf
