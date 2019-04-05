open Module_version

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      let __versioned__ = true

      (* TODO : version Sparse_ledger *)
      type t = {ledger: Sparse_ledger.t} [@@deriving sexp, bin_io]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1
end

type t = Stable.Latest.t = {ledger: Sparse_ledger.t} [@@deriving sexp]
