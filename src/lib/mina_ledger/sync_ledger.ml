open Core_kernel
open Mina_base

module Hash = struct
  include Ledger_hash.Stable.V1

  let to_base58_check = Ledger_hash.to_base58_check

  let merge = Ledger_hash.merge

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = Ledger_hash.of_digest (Lazy.force Account.empty_digest)
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

  let account_subtree_height = 6
end)

module Any_ledger = Syncable_ledger.Make (struct
  module Addr = Ledger.Location.Addr
  module MT = Ledger.Any_ledger.M
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 6
end)

module Db = Syncable_ledger.Make (struct
  module Addr = Ledger.Db.Addr
  module MT = Ledger.Db
  module Account = Account.Stable.Latest
  module Hash = Hash
  module Root_hash = Root_hash

  let account_subtree_height = 6
end)

module Answer = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V3 = struct
      type t =
        ( Ledger_hash.Stable.V1.t
        , Account.Stable.V2.t )
        Syncable_ledger.Answer.Stable.V2.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end

    module V2 = struct
      type t =
        ( Ledger_hash.Stable.V1.t
        , Account.Stable.V2.t )
        Syncable_ledger.Answer.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest x = Syncable_ledger.Answer.Stable.V1.to_latest Fn.id x

      (* Not a standard versioning function *)

      (** Attempts to downgrade v3 -> v2 *)
      let from_v3 : V3.t -> t Or_error.t =
       fun x -> Syncable_ledger.Answer.Stable.V1.from_v2 x
    end
  end]

  (* unused `rec` flag warning *)
  [@@@warning "-39"]

  (* TODO: generate this in ppx_version: issue #12111 *)
  type t = (Ledger_hash.t, Account.t) Syncable_ledger.Answer.t
    constraint t = Stable.Latest.t
  [@@deriving sexp, to_yojson]
end

module Query = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V2.t
      [@@deriving sexp, to_yojson, hash, compare]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        Ledger.Location.Addr.Stable.V1.t Syncable_ledger.Query.Stable.V1.t
      [@@deriving sexp, to_yojson, hash, compare]

      let to_latest : t -> V2.t = Syncable_ledger.Query.Stable.V1.to_latest

      (* Not a standard versioning function *)

      (* Attempts to downgrade v2 -> v1 *)
      let from_v2 : V2.t -> t = function
        | What_child_hashes (a, _) ->
            What_child_hashes a
        | What_contents a ->
            What_contents a
        | Num_accounts ->
            Num_accounts
    end
  end]

  (* unused `rec` flag warning *)
  [@@@warning "-39"]

  (* TODO: generate this in ppx_version: issue #12111 *)
  type t = Ledger.Location.Addr.t Syncable_ledger.Query.t
    constraint t = Stable.Latest.t
  [@@deriving sexp, to_yojson, hash, compare]
end
