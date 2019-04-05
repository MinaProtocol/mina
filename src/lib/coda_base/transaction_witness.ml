module Stable = struct
  module V1 = struct
    module T = struct
      type t = {ledger: Sparse_ledger.Stable.V1.t}
      [@@deriving sexp, bin_io, version]
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t = {ledger: Sparse_ledger.Stable.Latest.t}
[@@deriving sexp]
