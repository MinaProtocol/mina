open Core

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { delegator: Account.Index.Stable.V1.t
        ; curr_ledger: Sparse_ledger.Stable.V1.t
        ; epoch_ledger: Sparse_ledger.Stable.V1.t
        ; private_key: Signature_lib.Private_key.Stable.V1.t }
      [@@deriving bin_io, sexp, version]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  { delegator: Account.Index.t
  ; curr_ledger: Sparse_ledger.Stable.V1.t
  ; epoch_ledger: Sparse_ledger.Stable.V1.t
  ; private_key: Signature_lib.Private_key.t }
[@@deriving sexp]
