open Core
open Import

type t =
  { proposer: Public_key.Compressed.t
  ; other_recipient: Public_key.Compressed.t option }
[@@deriving sexp, bin_io, compare, eq]
