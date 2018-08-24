module Make (Inputs : sig
  val depth : int

  val num_accts : int
end) =
struct
  open Merkle_ledger.Test_ledger

  module Root_hash = struct
    include Hash

    type t = hash [@@deriving bin_io, compare, hash, sexp, compare]

    type account = Account.t

    let to_hash (x: t) = x

    let equal h1 h2 = compare_hash h1 h2 = 0
  end

  module L = struct
    module Ledger = Merkle_ledger.Ledger.Make (Key) (Account) (Hash) (Inputs)
    include Merkle_ledger.Test.Ledger (Ledger)

    type path = Path.t

    type addr = Addr.t

    type account = Account.t

    type hash = Root_hash.t
  end

  module SL =
    Syncable_ledger.Make (L.Addr) (Account) (Root_hash) (Root_hash) (L)
      (struct
        let subtree_height = 3
      end)

  module SR =
    Syncable_ledger.Make_sync_responder (L.Addr) (Account) (Root_hash)
      (Root_hash)
      (L)
      (SL)

  let num_accts = Inputs.num_accts
end
