open Core_kernel

module Hash = struct
  include Ledger_hash

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = hash_account Account.empty
end

module Root_hash = struct
  include Ledger_hash

  let to_hash (h : t) =
    Ledger_hash.of_digest (h :> Snark_params.Tick.Pedersen.Digest.t)
end

module Mask = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Ledger
  module Account = Account.Stable.V1
  module Hash = Hash
  module Root_hash = Root_hash

  let subtree_height = 3
end)

module Db = Syncable_ledger.Make (struct
  module Addr = Ledger.Db.Addr
  module MT = Ledger.Db
  module Account = Account.Stable.V1
  module Hash = Hash
  module Root_hash = Root_hash

  let subtree_height = 3
end)

type answer =
  ( Ledger.Location.Addr.t
  , Ledger_hash.t
  , Account.Stable.V1.t )
  Syncable_ledger.answer
[@@deriving bin_io, sexp]

type query = Ledger.Location.Addr.t Syncable_ledger.query
[@@deriving bin_io, sexp]
