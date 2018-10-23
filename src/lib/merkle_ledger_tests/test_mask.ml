(* test_make.ml -- tests Merkle mask connected to underlying Merkle tree *)

open Core
open Test_stubs

let%test_module "Test mask connected to underlying Merkle tree" =
  ( module struct
    module Database = Merkle_ledger.Database

    module type Test_intf = sig
      module Location : Merkle_ledger.Location_intf.S

      module Base_db :
        Merkle_mask.Base_merkle_tree_intf.S
        with module Addr = Location.Addr
         and type account := Account.t
         and type hash := Hash.t
         and type key := Key.t
         and type location := Location.t

      module Mask :
        Merkle_mask.Masking_merkle_tree_intf.S
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type parent := Base_db.t

      module Maskable :
        Merkle_mask.Maskable_merkle_tree_intf.S
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t

      val with_instances : (Maskable.t -> Mask.t -> 'a) -> 'a
    end

    module Make (Test : Test_intf) = struct
      let%test "dummy test" = Test.with_instances (fun _maskable _mask -> true)
    end

    module Make_maskable_and_mask (Depth : sig
      val depth : int
    end) =
    Make (struct
      module Location = Merkle_ledger.Location.Make (Depth)

      (* underlying Merkle tree *)
      module Base_db : sig
        include Merkle_mask.Base_merkle_tree_intf.S
                with module Addr = Location.Addr
                 and type account := Account.t
                 and type hash := Hash.t
                 and type key := Key.t
                 and type location := Location.t
      end =
        Database.Make (Key) (Account) (Hash) (Depth) (Location)
          (In_memory_kvdb)
          (In_memory_sdb)
          (Storage_locations)

      (* the mask tree *)
      module Mask :
        Merkle_mask.Masking_merkle_tree_intf.S
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type parent := Base_db.t =
        Merkle_mask.Masking_merkle_tree.Make (Key) (Account) (Hash) (Location)
          (Base_db)

      (* tree that can register masks *)
      module Maskable :
        Merkle_mask.Maskable_merkle_tree_intf.S
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t =
        Merkle_mask.Maskable_merkle_tree.Make (Key) (Account) (Hash) (Location)
          (Base_db)
          (Mask)

      (* test runner *)
      let with_instances f =
        let maskable = Maskable.create () in
        let mask = Mask.create () in
        f maskable mask
    end)

    module Depth_4 = struct
      let depth = 4
    end

    module Mdb_d4 = Make_maskable_and_mask (Depth_4)

    module Depth_30 = struct
      let depth = 30
    end

    module Mdb_d30 = Make_maskable_and_mask (Depth_30)
  end )
