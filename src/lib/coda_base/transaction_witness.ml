type t = {ledger: Sparse_ledger.t; pending_coinbases: Pending_coinbase.t}
[@@deriving sexp, bin_io]
