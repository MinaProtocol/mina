(* test_make.ml -- tests Merkle mask connected to underlying Merkle tree *)

open Core
open Test_stubs

let%test_module "Test mask connected to underlying Merkle tree" =
  ( module struct
    module Database = Merkle_ledger.Database

    module type Test_intf = sig
      val depth : int

      module Location : Merkle_ledger.Location_intf.S

      module Base :
        Merkle_mask.Base_merkle_tree_intf.S
        with module Addr = Location.Addr
         and module Location = Location
         and type account := Account.t
         and type root_hash := Hash.t
         and type hash := Hash.t
         and type key := Key.t

      type base = Base.t

      module Mask :
        Merkle_mask.Masking_merkle_tree_intf.S
        with module Addr = Location.Addr
         and module Location = Location
         and module Attached.Addr = Location.Addr
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type parent := Base.t

      module Maskable :
        Merkle_mask.Maskable_merkle_tree_intf.S
        with module Location = Location
         and module Addr = Location.Addr
        with type account := Account.t
         and type key := Key.t
         and type root_hash := Hash.t
         and type hash := Hash.t
         and type unattached_mask := Mask.t
         and type attached_mask := Mask.Attached.t
         and type t := base

      val with_instances : (base -> Mask.t -> 'a) -> 'a

      val with_chain : (base -> Mask.Attached.t -> Mask.Attached.t -> 'a) -> 'a
      (** Here we provide a base ledger and two layers of attached masks
       * one ontop another *)
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

      let dummy_account = Quickcheck.random_value Account.gen

      let create_new_account_exn mask ({Account.public_key; _} as account) =
        let action, location =
          Mask.Attached.get_or_create_account_exn mask public_key account
        in
        match action with
        | `Existed -> failwith "Expected to allocate a new account"
        | `Added -> location

      let parent_create_new_account_exn parent
          ({Account.public_key; _} as account) =
        let action, location =
          Maskable.get_or_create_account_exn parent public_key account
        in
        match action with
        | `Existed -> failwith "Expected to allocate a new account"
        | `Added -> location

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

      let%test_unit "commit at layer2, dumps to layer1, not in base" =
        Test.with_chain (fun base level1 level2 ->
            Mask.Attached.set level2 dummy_location dummy_account ;
            (* verify account is in the layer2 mask *)
            assert (
              Mask.Attached.For_testing.location_in_mask level2 dummy_location
            ) ;
            Mask.Attached.commit level2 ;
            (* account is no longer in layer2 *)
            assert (
              not
                (Mask.Attached.For_testing.location_in_mask level2
                   dummy_location) ) ;
            (* account is still not in base *)
            assert (Option.is_none @@ Maskable.get base dummy_location) ;
            (* account is present in layer1 *)
            assert (
              Mask.Attached.For_testing.location_in_mask level1 dummy_location
            ) )

      let%test "register and unregister mask" =
        Test.with_instances (fun maskable mask ->
            let (attached_mask : Mask.Attached.t) =
              Maskable.register_mask maskable mask
            in
            try
              let (_unattached_mask : Mask.t) =
                Maskable.unregister_mask_exn maskable attached_mask
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

      let%test_unit "root hash invariant if interior changes but not accounts"
          =
        if Test.depth <= 8 then
          Test.with_instances (fun maskable mask ->
              let attached_mask = Maskable.register_mask maskable mask in
              Mask.Attached.set attached_mask dummy_location dummy_account ;
              (* Make some accounts *)
              let num_accounts = 1 lsl Test.depth in
              let gen_values gen =
                Quickcheck.random_value
                  (Quickcheck.Generator.list_with_length num_accounts gen)
              in
              let public_keys = Key.gen_keys num_accounts in
              let balances = gen_values Balance.gen in
              let accounts =
                List.map2_exn public_keys balances
                  ~f:(fun public_key balance ->
                    Account.create public_key balance )
              in
              List.iter accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn attached_mask account ) ;
              (* Set some inner hashes *)
              let reset_hash_of_parent_of_index i =
                let a1 = List.nth_exn accounts i in
                let key = Account.public_key_of_account a1 in
                let location =
                  Mask.Attached.location_of_key attached_mask key
                  |> Option.value_exn
                in
                let addr = Test.Location.to_path_exn location in
                let parent_addr =
                  Test.Location.Addr.parent addr |> Or_error.ok_exn
                in
                Mask.Attached.set_inner_hash_at_addr_exn attached_mask
                  parent_addr Hash.empty_account
              in
              let root_hash = Mask.Attached.merkle_root attached_mask in
              reset_hash_of_parent_of_index 0 ;
              reset_hash_of_parent_of_index 3 ;
              let root_hash' = Mask.Attached.merkle_root attached_mask in
              assert (Hash.equal root_hash root_hash') )

      let%test "mask and parent agree on Merkle root before set" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let mask_merkle_root = Mask.Attached.merkle_root attached_mask in
            let maskable_merkle_root = Maskable.merkle_root maskable in
            Hash.equal mask_merkle_root maskable_merkle_root )

      let%test "mask and parent agree on Merkle root after set" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* the order of sets matters here; if we set in the mask first,
               the set in the maskable notifies the mask, which then removes
               the account, changing the Merkle root to what it was before the set
             *)
            Maskable.set maskable dummy_location dummy_account ;
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            let mask_merkle_root = Mask.Attached.merkle_root attached_mask in
            let maskable_merkle_root = Maskable.merkle_root maskable in
            (* verify root address in mask *)
            Mask.Attached.For_testing.address_in_mask attached_mask
              (Mask.Addr.root ())
            && Hash.equal mask_merkle_root maskable_merkle_root )

      let%test_unit "add and retrieve a block of accounts" =
        (* see similar test in test_database *)
        if Test.depth <= 8 then
          Test.with_instances (fun maskable mask ->
              let attached_mask = Maskable.register_mask maskable mask in
              let num_accounts = 1 lsl Test.depth in
              let gen_values gen =
                Quickcheck.random_value
                  (Quickcheck.Generator.list_with_length num_accounts gen)
              in
              let public_keys = Key.gen_keys num_accounts in
              let balances = gen_values Balance.gen in
              let accounts =
                List.map2_exn public_keys balances
                  ~f:(fun public_key balance ->
                    Account.create public_key balance )
              in
              List.iter accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn attached_mask account ) ;
              let retrieved_accounts =
                Mask.Attached.get_all_accounts_rooted_at_exn attached_mask
                  (Mask.Addr.root ())
              in
              assert (List.length accounts = List.length retrieved_accounts) ;
              assert (
                List.equal ~equal:Account.equal accounts retrieved_accounts )
          )

      let%test_unit "removing accounts from mask restores Merkle root" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts = 5 in
            let keys = Key.gen_keys num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let accounts = List.map2_exn keys balances ~f:Account.create in
            let merkle_root0 = Mask.Attached.merkle_root attached_mask in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn attached_mask account ) ;
            let merkle_root1 = Mask.Attached.merkle_root attached_mask in
            (* adding accounts should change the Merkle root *)
            assert (not (Hash.equal merkle_root0 merkle_root1)) ;
            Mask.Attached.remove_accounts_exn attached_mask keys ;
            (* should see original Merkle root after removing the accounts *)
            let merkle_root2 = Mask.Attached.merkle_root attached_mask in
            assert (Hash.equal merkle_root2 merkle_root0) )

      let%test_unit "removing accounts from parent restores Merkle root" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts = 5 in
            let keys = Key.gen_keys num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let accounts = List.map2_exn keys balances ~f:Account.create in
            let merkle_root0 = Mask.Attached.merkle_root attached_mask in
            (* add accounts to parent *)
            List.iter accounts ~f:(fun account ->
                ignore @@ parent_create_new_account_exn maskable account ) ;
            (* observe Merkle root in mask *)
            let merkle_root1 = Mask.Attached.merkle_root attached_mask in
            (* adding accounts should change the Merkle root *)
            assert (not (Hash.equal merkle_root0 merkle_root1)) ;
            Mask.Attached.remove_accounts_exn attached_mask keys ;
            (* should see original Merkle root after removing the accounts *)
            let merkle_root2 = Mask.Attached.merkle_root attached_mask in
            assert (Hash.equal merkle_root2 merkle_root0) )

      let%test_unit "removing accounts from parent and mask restores Merkle \
                     root" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts_parent = 5 in
            let num_accounts_mask = 5 in
            let num_accounts = num_accounts_parent + num_accounts_mask in
            let keys = Key.gen_keys num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let accounts = List.map2_exn keys balances ~f:Account.create in
            let parent_accounts, mask_accounts =
              List.split_n accounts num_accounts_parent
            in
            let merkle_root0 = Mask.Attached.merkle_root attached_mask in
            (* add accounts to parent *)
            List.iter parent_accounts ~f:(fun account ->
                ignore @@ parent_create_new_account_exn maskable account ) ;
            (* add accounts to mask *)
            List.iter mask_accounts ~f:(fun account ->
                ignore @@ create_new_account_exn attached_mask account ) ;
            (* observe Merkle root in mask *)
            let merkle_root1 = Mask.Attached.merkle_root attached_mask in
            (* adding accounts should change the Merkle root *)
            assert (not (Hash.equal merkle_root0 merkle_root1)) ;
            (* remove accounts from mask and parent *)
            Mask.Attached.remove_accounts_exn attached_mask keys ;
            (* should see original Merkle root after removing the accounts *)
            let merkle_root2 = Mask.Attached.merkle_root attached_mask in
            assert (Hash.equal merkle_root2 merkle_root0) )

      let%test_unit "fold of addition over account balances in parent and mask"
          =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts_parent = 5 in
            let num_accounts_mask = 5 in
            let num_accounts = num_accounts_parent + num_accounts_mask in
            let keys = Key.gen_keys num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let accounts = List.map2_exn keys balances ~f:Account.create in
            let total =
              List.fold balances ~init:0 ~f:(fun accum balance ->
                  Balance.to_int balance + accum )
            in
            let parent_accounts, mask_accounts =
              List.split_n accounts num_accounts_parent
            in
            (* add accounts to parent *)
            List.iter parent_accounts ~f:(fun account ->
                ignore @@ parent_create_new_account_exn maskable account ) ;
            (* add accounts to mask *)
            List.iter mask_accounts ~f:(fun account ->
                ignore @@ create_new_account_exn attached_mask account ) ;
            (* folding over mask also folds over maskable *)
            let retrieved_total =
              Mask.Attached.foldi attached_mask ~init:0
                ~f:(fun _addr total account ->
                  Balance.to_int (Account.balance account) + total )
            in
            assert (Int.equal retrieved_total total) )

      let%test_unit "reuse of locations for removed accounts" =
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts = 5 in
            let keys = Key.gen_keys num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let accounts = List.map2_exn keys balances ~f:Account.create in
            assert (
              Option.is_none
                (Mask.Attached.For_testing.current_location attached_mask) ) ;
            (* add accounts to mask *)
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn attached_mask account ) ;
            assert (
              Option.is_some
                (Mask.Attached.For_testing.current_location attached_mask) ) ;
            (* remove accounts *)
            Mask.Attached.remove_accounts_exn attached_mask keys ;
            assert (
              Option.is_none
                (Mask.Attached.For_testing.current_location attached_mask) ) )
    end

    module type Depth_S = sig
      val depth : int
    end

    module Make_maskable_and_mask_with_depth (Depth : Depth_S) = struct
      let depth = Depth.depth

      module Location : Merkle_ledger.Location_intf.S =
        Merkle_ledger.Location.Make (Depth)

      (* underlying Merkle tree *)
      module Base_db :
        Merkle_ledger.Database_intf.S
        with module Location = Location
         and module Addr = Location.Addr
         and type account := Account.t
         and type root_hash := Hash.t
         and type hash := Hash.t
         and type key := Key.t =
        Database.Make (Key) (Account) (Hash) (Depth) (Location)
          (In_memory_kvdb)
          (Storage_locations)

      module Any_base =
        Merkle_ledger.Any_ledger.Make_base (Key) (Account) (Hash) (Location)
          (Depth)
      module Base = Any_base.M

      type base = Base.t

      (* the mask tree *)
      module Mask :
        Merkle_mask.Masking_merkle_tree_intf.S
        with module Location = Location
         and module Addr = Location.Addr
         and module Attached.Addr = Location.Addr
        with type account := Account.t
         and type location := Location.t
         and type key := Key.t
         and type hash := Hash.t
         and type parent := Base.t =
        Merkle_mask.Masking_merkle_tree.Make (Key) (Account) (Hash) (Location)
          (Base)

      (* tree that can register masks *)
      module Maskable :
        Merkle_mask.Maskable_merkle_tree_intf.S
        with module Addr = Location.Addr
         and module Location = Location
        with type account := Account.t
         and type key := Key.t
         and type root_hash := Hash.t
         and type hash := Hash.t
         and type unattached_mask := Mask.t
         and type attached_mask := Mask.Attached.t
         and type t := base =
        Merkle_mask.Maskable_merkle_tree.Make (Key) (Account) (Hash) (Location)
          (Base)
          (Mask)

      (* test runner *)
      let with_instances f =
        let db = Base_db.create () in
        let maskable = Any_base.cast (module Base_db) db in
        let mask = Mask.create () in
        f maskable mask

      let with_chain f =
        with_instances (fun maskable mask ->
            let attached1 = Maskable.register_mask maskable mask in
            let pack2 = Any_base.cast (module Mask.Attached) attached1 in
            let mask2 = Mask.create () in
            let attached2 = Maskable.register_mask pack2 mask2 in
            f maskable attached1 attached2 )
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
