open Fold_lib

type t =
  { staged_ledger_hash: Staged_ledger_hash.t
  ; ledger_hash: Ledger_hash.t
  ; timestamp: Block_time.t }
[@@deriving bin_io, eq, sexp]

let fold ({staged_ledger_hash; ledger_hash; timestamp} : t) =
  let open Fold in
  Staged_ledger_hash.fold staged_ledger_hash
  +> Ledger_hash.fold ledger_hash
  +> Block_time.fold timestamp
