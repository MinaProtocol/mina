open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type t = {ledger: Sparse_ledger.Stable.V2.t} [@@deriving sexp]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t = {ledger: Sparse_ledger.Stable.V1.t} [@@deriving sexp]

    let to_latest {ledger} =
      {V2.ledger= Sparse_ledger.Stable.V1.to_latest ledger}

    let of_latest {V2.ledger} =
      let open Result.Let_syntax in
      let%map ledger = Sparse_ledger.Stable.V1.of_latest ledger in
      {ledger}
  end
end]

type t = Stable.Latest.t = {ledger: Sparse_ledger.t} [@@deriving sexp]
