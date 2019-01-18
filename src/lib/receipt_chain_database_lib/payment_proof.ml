open Core_kernel

type ('receipt_chain_hash, 'payment) t =
  {initial_receipt: 'receipt_chain_hash; payments: 'payment list}
[@@deriving eq, sexp, bin_io, yojson, compare, fields]
