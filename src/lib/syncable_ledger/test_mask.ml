open Core

module Make (Depth : sig
  val depth : int
end) =
struct
  (* 
module type Input_intf = sig
  module Root_hash : sig
    type t [@@deriving bin_io, compare, hash, sexp, compare]

    val equal : t -> t -> bool
  end

  module L :
    Ledger_intf
    with type root_hash := Root_hash.t
     and type key := Merkle_ledger_tests.Test_stubs.Key.t

  module SL :
    Syncable_ledger.S
    with type merkle_tree := L.t
     and type hash := L.hash
     and type root_hash := Root_hash.t
     and type addr := L.addr
     and type merkle_path := L.path
     and type account := L.account

  module SR = SL.Responder
end

 *)
  open Merkle_ledger_tests.Test_stubs

  module Hash = struct
    type t = Hash.t [@@deriving sexp, hash, compare, bin_io, eq]

    type account = Account.t

    let merge = Hash.merge

    let hash_account = Hash.hash_account

    let to_hash = Fn.id

    let empty_account = hash_account Account.empty
  end

  module Location : Merkle_ledger.Location_intf.S =
    Merkle_ledger.Location.Make (Depth)

  module L = struct
    (* TODO: copy from merkle_tree_test/test_mask *)

    open Merkle_ledger_tests.Test_stubs

    module Base_db :
      Merkle_ledger.Database_intf.S
      with module Location = Location
       and module Addr = Location.Addr
       and type account := Account.t
       and type root_hash := Hash.t
       and type hash := Hash.t
       and type key := Key.t
       and type key_set := Key.Set.t =
      Merkle_ledger.Database.Make (Key) (Account) (Hash) (Depth) (Location)
        (In_memory_kvdb)
        (Storage_locations)

    module Any_base =
      Merkle_ledger.Any_ledger.Make_base (Key) (Account) (Hash) (Location)
        (Depth)
    module Base = Any_base.M

    module Mask :
      Merkle_mask.Masking_merkle_tree_intf.S
      with module Location = Location
       and module Attached.Addr = Location.Addr
      with type account := Account.t
       and type location := Location.t
       and type key := Key.t
       and type key_set := Key.Set.t
       and type hash := Hash.t
       and type parent := Base.t =
      Merkle_mask.Masking_merkle_tree.Make (Key) (Account) (Hash) (Location)
        (Base)

    module Maskable :
      Merkle_mask.Maskable_merkle_tree_intf.S
      with module Addr = Location.Addr
       and module Location = Location
      with type account := Account.t
       and type key := Key.t
       and type key_set := Key.Set.t
       and type root_hash := Hash.t
       and type hash := Hash.t
       and type unattached_mask := Mask.t
       and type attached_mask := Mask.Attached.t
       and type t := Base.t =
      Merkle_mask.Maskable_merkle_tree.Make (Key) (Account) (Hash) (Location)
        (Base)
        (Mask)

    module MT = Maskable

    let load_ledger num_accounts (balance : int) =
      let db = Base_db.create () in
      let maskable = Any_base.cast (module Base_db) db in
      let keys = Key.gen_keys num_accounts in
      (* All the parents will have certain values *)
      List.iter keys ~f:(fun key ->
          let account =
            Account.create key (Currency.Balance.of_int (2 * balance))
          in
          let action, _ =
            Maskable.get_or_create_account_exn maskable key account
          in
          assert (action = `Added) ) ;
      let mask = Mask.create () in
      let attached_mask = Maskable.register_mask maskable mask in
      (* On the mask, all the children will have different values *)
      List.iter keys ~f:(fun key ->
          let account = Account.create key (Currency.Balance.of_int balance) in
          let action, location =
            Mask.Attached.get_or_create_account_exn attached_mask key account
          in
          match action with
          | `Existed -> Mask.Attached.set attached_mask location account
          | `Added -> failwith "Expected to re-use an existing account" ) ;
      (attached_mask, keys)

    include Mask.Attached

    type addr = Addr.t

    type account = Account.t

    type hash = Hash.t
  end

  module Root_hash = Hash

  module SL =
    Syncable_ledger.Make (L.Addr) (Account) (Hash) (Hash) (L)
      (struct
        let subtree_height = 3
      end)

  module SR = SL.Responder
end
