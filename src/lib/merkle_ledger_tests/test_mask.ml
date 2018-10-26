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
        Merkle_mask.Masking_merkle_tree_intf.S
        with module Addr = Location.Addr
         and module Attached.Addr = Location.Addr
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
         and type unattached_mask := Mask.t
         and type attached_mask := Mask.Attached.t

      val with_instances : (Maskable.t -> Mask.t -> 'a) -> 'a
    end

    module Make (Test : Test_intf) = struct
      module Maskable = Test.Maskable
      module Mask = Test.Mask

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

      let%test "parent, mask agree on set" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            Maskable.set maskable dummy_location dummy_account ;
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            let maskable_result = Maskable.get maskable dummy_location in
            let mask_result = Mask.Attached.get attached_mask dummy_location in
            Option.is_some maskable_result
            && Option.is_some mask_result
            &&
            let maskable_account = Option.value_exn maskable_result in
            let mask_account = Option.value_exn mask_result in
            Account.equal maskable_account mask_account )

      let compare_maskable_mask_hashes ?(check_hash_in_mask = false) maskable
          mask addr =
        let root = Mask.Attached.Addr.root () in
        let rec test_hashes_at_address addr =
          ( (not check_hash_in_mask)
          || Mask.Attached.For_testing.address_in_mask mask addr )
          &&
          let maybe_mask_hash = Mask.Attached.get_hash mask addr in
          Option.is_some maybe_mask_hash
          &&
          let mask_hash = Option.value_exn maybe_mask_hash in
          let maskable_hash =
            Maskable.get_inner_hash_at_addr_exn maskable addr
          in
          Hash.equal mask_hash maskable_hash
          &&
          if Mask.Addr.equal root addr then true
          else test_hashes_at_address (Mask.Attached.Addr.parent_exn addr)
        in
        test_hashes_at_address addr

      let%test "parent, mask agree on hashes; set in both mask and parent" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set in both parent and mask *)
            Maskable.set maskable dummy_location dummy_account ;
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* verify all hashes to root are same in mask and parent *)
            compare_maskable_mask_hashes ~check_hash_in_mask:true maskable
              attached_mask dummy_address )

      let%test "parent, mask agree on hashes; set only in parent" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set only in parent *)
            Maskable.set maskable dummy_location dummy_account ;
            (* verify all hashes to root are same in mask and parent *)
            compare_maskable_mask_hashes maskable attached_mask dummy_address
        )

      let%test "mask delegates to parent" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set to parent, get from mask *)
            Maskable.set maskable dummy_location dummy_account ;
            let mask_result = Mask.Attached.get attached_mask dummy_location in
            Option.is_some mask_result
            &&
            let mask_account = Option.value_exn mask_result in
            Account.equal dummy_account mask_account )

      let%test "mask prune after parent notification" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set to mask *)
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* verify account is in mask *)
            if
              Mask.Attached.For_testing.location_in_mask attached_mask
                dummy_location
            then (
              Maskable.set maskable dummy_location dummy_account ;
              (* verify account pruned from mask *)
              not
                (Mask.Attached.For_testing.location_in_mask attached_mask
                   dummy_location) )
            else false )

      let%test "commit puts mask contents in parent, flushes mask" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set to mask *)
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* verify account is in mask *)
            if
              Mask.Attached.For_testing.location_in_mask attached_mask
                dummy_location
            then (
              Mask.Attached.commit attached_mask ;
              (* verify account no longer in mask but is in parent *)
              (not
                 (Mask.Attached.For_testing.location_in_mask attached_mask
                    dummy_location))
              && Option.is_some (Maskable.get maskable dummy_location) )
            else false )

      let%test "register and unregister mask" =
        Test.with_instances (fun maskable mask ->
            let (attached_mask : Mask.Attached.t) =
              Maskable.register_mask maskable mask
            in
            try
              let (_unattached_mask : Mask.t) =
                Maskable.unregister_mask_exn attached_mask
              in
              true
            with Failure _ -> false )

      let%test "mask and parent agree on Merkle path" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* set affects hashes along the path P from location to the root, while the Merkle path for the location 
               contains the siblings of P elements; to observe a hash in the Merkle path changed by the set, choose an 
               address that is a sibling of an element in P; the Merkle path for that address will include a P element
             *)
            let address =
              dummy_address |> Maskable.Addr.parent_exn
              |> Maskable.Addr.sibling
            in
            let mask_merkle_path =
              Mask.Attached.merkle_path_at_addr_exn attached_mask address
            in
            Maskable.set maskable dummy_location dummy_account ;
            let maskable_merkle_path =
              Maskable.merkle_path_at_addr_exn maskable address
            in
            mask_merkle_path = maskable_merkle_path )
    end

    module type Depth_S = sig
      val depth : int
    end

    module Make_maskable_and_mask_with_depth (Depth : Depth_S) = struct
      let depth = Depth.depth

      module Location = Merkle_ledger.Location.Make (Depth)

      (* underlying Merkle tree *)
      module Base_db : sig
        include
          Merkle_mask.Base_merkle_tree_intf.S
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
        with module Addr = Location.Addr
         and module Attached.Addr = Location.Addr
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
         and type unattached_mask := Mask.t
         and type attached_mask := Mask.Attached.t =
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
