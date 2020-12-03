open Core_kernel

module Hash = struct
  include Ledger_hash.Stable.V1

  let to_string = Ledger_hash.to_string

  let merge = Ledger_hash.merge

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = Ledger_hash.of_digest Account.empty_digest
end

module Root_hash = struct
  include Ledger_hash

  let to_hash (h : t) = Ledger_hash.of_digest (h :> Random_oracle.Digest.t)
end

module Mask = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Ledger
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 3
end)

module Any_ledger = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Ledger.Any_ledger.M
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 3
end)

module Db = Syncable_ledger.Make (struct
  module Addr = Ledger.Db.Addr
  module MT = Ledger.Db
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 3
end)

module Answer = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Ledger_hash.Stable.V1.t
        , Account.Stable.V1.t )
        Syncable_ledger.Answer.Stable.V1.t
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]
end

module Query = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end
