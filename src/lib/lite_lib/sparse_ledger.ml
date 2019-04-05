module Hash = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        let __versioned__ = true

        type t = Lite_base.Pedersen.Digest.t
        [@@deriving sexp, bin_io, eq, compare]
      end

      include T

      let merge = Merkle_path.merge
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, eq, compare]

  let merge = Stable.Latest.merge
end

include Sparse_ledger_lib.Sparse_ledger.Make
          (Hash.Stable.V1)
          (Lite_base.Public_key.Compressed.Stable.V1)
          (struct
            include Account.Stable.V1

            let data_hash = Account.digest
          end)
