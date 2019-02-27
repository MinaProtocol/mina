open Core

type t =
  { delegator: Account.Index.t
  ; ledger: Sparse_ledger.t
  ; private_key: Signature_lib.Private_key.t
  ; pending_coinbase_collection: Pending_coinbase.t }
[@@deriving bin_io, sexp]
