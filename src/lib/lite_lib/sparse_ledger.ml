include Sparse_ledger_lib.Sparse_ledger.Make (struct
            type t = Lite_base.Pedersen.Digest.t
            [@@deriving sexp, bin_io, eq, compare]

            let merge = Merkle_path.merge
          end)
          (Lite_base.Public_key.Compressed)
          (struct
            include Account

            let hash = Account.digest
          end)
