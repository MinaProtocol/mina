open Core_kernel
open Module_version

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

module Answer = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t =
          ( Ledger.Location.Addr.t
          , Ledger_hash.Stable.V1.t
          , Account.Stable.V1.t )
          Syncable_ledger.Answer.Stable.V1.t
        [@@deriving bin_io, sexp]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "sync_ledger_answer"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted from deriving list *)
  type t = Stable.Latest.t [@@deriving sexp]
end

module Query = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t =
          Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V1.t
        [@@deriving bin_io, sexp]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "sync_ledger_query"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted from deriving list *)
  type t = Stable.Latest.t [@@deriving sexp]
end
