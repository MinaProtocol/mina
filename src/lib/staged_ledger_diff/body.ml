open Core_kernel

(* TODO Consider moving to a different location. as in future this won't be only about block body *)
module Tag = struct
  type t = Body [@@deriving enum]
  (* In future: | EpochLedger |... *)
end

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

let serializize_with_len_and_tag b =
  let len = Stable.V1.bin_size_t b in
  let bs' = Bigstring.create (len + 5) in
  ignore (Stable.V1.bin_write_t bs' ~pos:5 b : int) ;
  Bigstring.set_uint8_exn ~pos:4 bs' (Tag.to_enum Body) ;
  Bigstring.set_uint32_le_exn ~pos:0 bs' (len + 1) ;
  bs'

let compute_reference =
  Fn.compose snd
  @@ Fn.compose
       (Bitswap_block.blocks_of_data ~max_block_size:262144)
       serializize_with_len_and_tag
