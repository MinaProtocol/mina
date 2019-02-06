open Core_kernel

include Syncable_ledger.Make (Ledger.Location.Addr) (Account)
          (struct
            include Ledger_hash

            let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

            let empty_account = hash_account Account.empty
          end)
          (struct
            include Ledger_hash

            let to_hash (h : t) =
              Ledger_hash.of_digest (h :> Snark_params.Tick.Pedersen.Digest.t)
          end)
          (struct
            include Ledger

            let f = Account.hash
          end)
          (struct
            let subtree_height = 3
          end)

type answer =
  (Ledger.Location.Addr.t, Ledger_hash.t, Account.t) Syncable_ledger.answer
[@@deriving bin_io, sexp]

type query = Ledger.Location.Addr.t Syncable_ledger.query
[@@deriving bin_io, sexp]
