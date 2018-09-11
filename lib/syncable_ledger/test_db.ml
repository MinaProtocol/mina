open Core

module Make (Depth : sig
  val depth : int

  val num_accts : int
end) =
struct
  open Merkle_ledger_tests.Test_stubs

  module Hash = struct
    type t = Hash.t [@@deriving sexp, hash, compare, bin_io, eq]

    type account = Account.t

    let empty = Hash.empty

    let empty_hash = Hash.empty

    let merge = Hash.merge

    let hash_account = Hash.hash_account

    let to_hash = Fn.id
  end

  module L = struct
    module MT =
      Merkle_ledger.Database.Make (Key) (Account) (Hash) (Depth)
        (In_memory_kvdb)
        (In_memory_sdb)
    module Addr = MT.Addr

    type root_hash = Hash.t

    type hash = Hash.t

    type account = Account.t

    type key = MT.location

    type addr = Addr.t

    type path = MT.Path.t

    type t = MT.t

    let depth = Depth.depth

    let length = MT.length

    let merkle_path_at_addr_exn = MT.merkle_path_at_addr_exn

    let merkle_root = MT.merkle_root

    let get_all_accounts_rooted_at_exn = MT.get_all_accounts_rooted_at_exn

    let set_all_accounts_rooted_at_exn = MT.set_all_accounts_rooted_at_exn

    let get_inner_hash_at_addr_exn = MT.get_inner_hash_at_addr_exn

    let set_inner_hash_at_addr_exn = MT.set_inner_hash_at_addr_exn

    let load_ledger num_accounts (balance: int) =
      let ledger = MT.create ~key_value_db_dir:"" ~stack_db_file:"" in
      let keys =
        List.init num_accounts ~f:(( + ) 1) |> List.map ~f:Int.to_string
      in
      List.iter keys ~f:(fun key ->
          let account = Account.create key balance in
          MT.get_or_create_account_exn ledger key account |> ignore ) ;
      (ledger, keys)
  end

  module Root_hash = Hash

  module SL =
    Syncable_ledger.Make (L.Addr) (Account) (Hash) (Hash) (L)
      (struct
        let subtree_height = 3
      end)

  module SR = SL.Responder

  let num_accts = Depth.num_accts
end
