open Core

type t =
  { delegator: Account.Index.t
  ; ledger: Sparse_ledger.t
  ; private_key: Signature_lib.Private_key.t }
[@@deriving bin_io, sexp]
