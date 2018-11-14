open Fold_lib

type t =
  { ledger_builder_hash: Ledger_builder_hash.t
  ; ledger_hash: Ledger_hash.t
  ; timestamp: Block_time.t }
[@@deriving bin_io, eq, sexp]

let fold ({ledger_builder_hash; ledger_hash; timestamp} : t) =
  let open Fold in
  Ledger_builder_hash.fold ledger_builder_hash
  +> Ledger_hash.fold ledger_hash
  +> Block_time.fold timestamp
