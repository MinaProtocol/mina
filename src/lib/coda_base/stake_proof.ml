open Core

type t =
  { delegator: Account.Index.t
  ; ledger: Sparse_ledger.t
  ; private_key: Signature_lib.Private_key.t }
[@@deriving bin_io, sexp]

let dummy =
  { delegator= 0
  ; ledger=
      Sparse_ledger.of_root (Ledger_hash.of_hash Snark_params.Tick.Field.zero)
  ; private_key= Snark_params.Tick.Inner_curve.Scalar.zero }
