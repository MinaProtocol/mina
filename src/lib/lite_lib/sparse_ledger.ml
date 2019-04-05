module Hash = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Lite_base.Pedersen.Digest.t
        [@@deriving sexp, bin_io, eq, compare]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, eq, compare]

  let merge = Merkle_path.merge
end

include Sparse_ledger_lib.Sparse_ledger.Make
          (Hash)
          (Lite_base.Public_key.Compressed)
          (struct
            include Account

            let data_hash = Account.digest
          end)
