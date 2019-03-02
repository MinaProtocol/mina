type t =
  {ledger: Sparse_ledger.t (*; coinbase_stack: Pending_coinbase.Stack.t*)}
[@@deriving sexp, bin_io]
