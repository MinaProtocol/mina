open Core

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { delegator: Account.Index.t
        ; ledger: Sparse_ledger.Stable.V1.t
        ; private_key: Signature_lib.Private_key.t }
      [@@deriving bin_io, sexp, version {asserted}]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t =
  { delegator: Account.Index.t
  ; ledger: Sparse_ledger.Stable.V1.t
  ; private_key: Signature_lib.Private_key.t }
[@@deriving sexp]
