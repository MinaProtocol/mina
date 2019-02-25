type t =
  {ledger: Sparse_ledger.t (*; pending_coinbases: Pending_coinbase.Stack.t*)}
[@@deriving sexp, bin_io]
