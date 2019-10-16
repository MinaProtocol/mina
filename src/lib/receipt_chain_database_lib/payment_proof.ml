open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('receipt_chain_hash, 'payment) t =
      {initial_receipt: 'receipt_chain_hash; payments: 'payment list}
    [@@deriving eq, sexp, yojson, compare, fields]
  end
end]

type ('receipt_chain_hash, 'payment) t =
      ('receipt_chain_hash, 'payment) Stable.Latest.t =
  {initial_receipt: 'receipt_chain_hash; payments: 'payment list}
[@@deriving eq, sexp, yojson, compare, fields]
