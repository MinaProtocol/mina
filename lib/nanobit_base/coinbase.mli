open Core
open Import

type t =
  { proposer: Public_key.Compressed.t
  ; fee_transfer: Fee_transfer.single option
  }
[@@deriving sexp, bin_io, compare, eq]
