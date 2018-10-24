(* test_make.ml -- tests Merkle mask connected to underlying Merkle tree *)

open Core
open Test_stubs

let%test_module "Test mask connected to underlying Merkle tree" =
  ( module struct
    module Database = Merkle_ledger.Database

    module type Test_intf = sig
      val depth : int

      module Location : Merkle_ledger.Location_intf.S

      module Base_db :
        Merkle_mask.Base_merkle_tree_intf.S
        with module Addr = Location.Addr
         and type account := Account.t
         and type hash := Hash.t
         and type key := Key.t
         and type location := Location.t

      module Mask :
        Merkle_mask.Masking_merkle_tree_intf.S with module Addr = Location.Addr
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type parent := Base_db.t

      module Maskable :
        Merkle_mask.Maskable_merkle_tree_intf.S
        with module Addr = Location.Addr
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type mask := Mask.t

      val with_instances : (Maskable.t -> Mask.t -> 'a) -> 'a
    end

    module Make (Test : Test_intf) = struct
      let directions =
        let rec add_direction count b accum =
          if count >= Test.depth then accum
          else
            let dir = if b then Direction.Right else Direction.Left in
            add_direction (count + 1) (not b) (dir :: accum)
        in
        add_direction 0 false []

      let dummy_address = Test.Location.Addr.of_directions directions

      let dummy_location = Test.Location.Account dummy_address

      let dummy_account = Account.create "not_really_a_public_key" 1000

      let%test "parent must be set in mask for set" =
        Test.with_instances (fun _maskable mask ->
            try
              Test.Mask.set mask dummy_location dummy_account ;
              false
            with Failure _ -> true )

      let%test "parent must be set in mask for get" =
        Test.with_instances (fun _maskable mask ->
            try
              ignore (Test.Mask.get mask dummy_location) ;
              false
            with Failure _ -> true )

      let%test "parent, mask agree on set" =
        Test.with_instances (fun maskable mask ->
            Test.Maskable.register_mask maskable mask ;
            Test.Maskable.set maskable dummy_location dummy_account ;
            Test.Mask.set mask dummy_location dummy_account ;
            let maskable_result = Test.Maskable.get maskable dummy_location in
            let mask_result = Test.Mask.get mask dummy_location in
            Option.is_some maskable_result
            && Option.is_some mask_result
            &&
            let maskable_account = Option.value_exn maskable_result in
            let mask_account = Option.value_exn mask_result in
            Account.equal maskable_account mask_account )

      let compare_maskable_mask_hashes ?(check_hash_in_mask= false) maskable
          mask addr =
        let root = Test.Mask.Addr.root () in
        let rec test_hashes_at_address addr =
          (not check_hash_in_mask || Test.Mask.address_in_mask mask addr)
          &&
          let maybe_mask_hash = Test.Mask.get_hash mask addr in
          Option.is_some maybe_mask_hash
          &&
          let mask_hash = Option.value_exn maybe_mask_hash in
          let maskable_hash =
            Test.Maskable.get_inner_hash_at_addr_exn maskable addr
          in
          Hash.equal mask_hash maskable_hash
          &&
          if Test.Mask.Addr.equal root addr then true
          else test_hashes_at_address (Test.Mask.Addr.parent_exn addr)
        in
        test_hashes_at_address addr

      let%test "parent, mask agree on hashes; set in both mask and parent" =
        Test.with_instances (fun maskable mask ->
            Test.Maskable.register_mask maskable mask ;
            (* set in both parent and mask *)
            Test.Maskable.set maskable dummy_location dummy_account ;
            Test.Mask.set mask dummy_location dummy_account ;
            (* verify all hashes to root are same in mask and parent *)
            compare_maskable_mask_hashes ~check_hash_in_mask:true maskable mask
              dummy_address )

      let%test "parent, mask agree on hashes; set only in parent" =
        Test.with_instances (fun maskable mask ->
            Test.Maskable.register_mask maskable mask ;
            (* set only in parent *)
            Test.Maskable.set maskable dummy_location dummy_account ;
            (* verify all hashes to root are same in mask and parent *)
            compare_maskable_mask_hashes maskable mask dummy_address )

      let%test "mask delegates to parent" =
        Test.with_instances (fun maskable mask ->
            Test.Maskable.register_mask maskable mask ;
            (* set to parent, get from mask *)
            Test.Maskable.set maskable dummy_location dummy_account ;
            let mask_result = Test.Mask.get mask dummy_location in
            Option.is_some mask_result
            &&
            let mask_account = Option.value_exn mask_result in
            Account.equal dummy_account mask_account )

      let%test "mask prune after parent notification" =
        Test.with_instances (fun maskable mask ->
            Test.Maskable.register_mask maskable mask ;
            (* set to mask *)
            Test.Mask.set mask dummy_location dummy_account ;
            (* verify account is in mask *)
            if Test.Mask.location_in_mask mask dummy_location then (
              Test.Maskable.set maskable dummy_location dummy_account ;
              (* verify account pruned from mask *)
              not (Test.Mask.location_in_mask mask dummy_location) )
            else false )
    end

    module type Depth_S = sig
      val depth : int
    end

    module Make_maskable_and_mask_with_depth (Depth : Depth_S) = struct
      let depth = Depth.depth

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
        Merkle_mask.Masking_merkle_tree_intf.S with module Addr = Location.Addr
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
        with module Addr = Location.Addr
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type mask := Mask.t =
        Merkle_mask.Maskable_merkle_tree.Make (Key) (Account) (Hash) (Location)
          (Base_db)
          (Mask)

      (* test runner *)
      let with_instances f =
        let maskable = Maskable.create () in
        let mask = Mask.create () in
        f maskable mask
    end

    module Make_maskable_and_mask (Depth : Depth_S) =
    Make (Make_maskable_and_mask_with_depth (Depth))

    module Depth_4 = struct
      let depth = 4
    end

    module Mdb_d4 = Make_maskable_and_mask (Depth_4)

    module Depth_30 = struct
      let depth = 30
    end

    module Mdb_d30 = Make_maskable_and_mask (Depth_30)
  end )
