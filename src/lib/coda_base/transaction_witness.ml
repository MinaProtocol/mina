open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = {ledger: Sparse_ledger.Stable.V1.t} [@@deriving sexp]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t = {ledger: Sparse_ledger.t} [@@deriving sexp]
