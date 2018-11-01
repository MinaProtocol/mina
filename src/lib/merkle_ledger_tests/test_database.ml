open Core
open Test_stubs

let%test_module "test functor on in memory databases" =
  ( module struct
    module Intf = Merkle_ledger.Intf
    module Database = Merkle_ledger.Database

    module type DB =
      Merkle_ledger.Database_intf.S
      with type key := Key.t
       and type account := Account.t
       and type hash := Hash.t

    module type Test_intf = sig
      val depth : int

      module Location : Merkle_ledger.Location_intf.S

      module Addr : Merkle_address.S

      module MT : DB with type location := Location.t

      val with_instance : (MT.t -> 'a) -> 'a
    end

    module Make (Test : Test_intf) = struct
      module MT = Test.MT

      let%test_unit "getting a non existing account returns None" =
        Test.with_instance (fun mdb ->
            Quickcheck.test MT.For_tests.gen_account_location
              ~f:(fun location -> assert (MT.get mdb location = None) ) )

      let create_new_account_exn mdb ({Account.public_key; _} as account) =
        let action, location =
          MT.get_or_create_account_exn mdb public_key account
        in
        match action with
        | `Existed -> failwith "Expected to allocate a new account"
        | `Added -> location

      let%test "add and retrieve an account" =
        Test.with_instance (fun mdb ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_account_exn mdb account in
            Account.equal (Option.value_exn (MT.get mdb location)) account )

      let%test "accounts are atomic" =
        Test.with_instance (fun mdb ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_account_exn mdb account in
            MT.set mdb location account ;
            let location' =
              MT.location_of_key mdb (Account.public_key account)
              |> Option.value_exn
            in
            location = location' && MT.get mdb location' = MT.get mdb location
        )

      let dedup_accounts accounts =
        List.dedup_and_sort accounts ~compare:(fun account1 account2 ->
            String.compare
              (Account.public_key account1)
              (Account.public_key account2) )

      let%test_unit "length" =
        Test.with_instance (fun mdb ->
            let open Quickcheck.Generator in
            let max_accounts = Int.min (1 lsl MT.depth) (1 lsl 5) in
            let gen_unique_nonzero_balance_accounts n =
              let open Quickcheck.Let_syntax in
              let%bind num_initial_accounts = Int.gen_incl 0 n in
              let%map accounts =
                list_with_length num_initial_accounts Account.gen
              in
              dedup_accounts accounts
            in
            let accounts =
              Quickcheck.random_value
                (gen_unique_nonzero_balance_accounts (max_accounts / 2))
            in
            let num_initial_accounts = List.length accounts in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn mdb account ) ;
            let result = MT.num_accounts mdb in
            [%test_eq: int] result num_initial_accounts )

      let%test "get_or_create_acount does not update an account if key \
                already exists" =
        Test.with_instance (fun mdb ->
            let public_key = Quickcheck.random_value String.gen in
            let balance =
              Quickcheck.random_value (Int.gen_incl 1 Int.max_value)
            in
            let account = Account.create public_key balance in
            let account' = Account.create public_key (balance + 1) in
            let location = create_new_account_exn mdb account in
            let action, location' =
              MT.get_or_create_account_exn mdb public_key account'
            in
            location = location'
            && action = `Existed
            && MT.get mdb location |> Option.value_exn <> account' )

      let%test_unit "get_or_create_account t account = location_of_key \
                     account.key" =
        Test.with_instance (fun mdb ->
            let accounts_gen =
              let open Quickcheck.Let_syntax in
              let max_height = Int.min MT.depth 5 in
              let%bind num_accounts = Int.gen_incl 0 (1 lsl max_height) in
              Quickcheck.Generator.list_with_length num_accounts Account.gen
            in
            let accounts = Quickcheck.random_value accounts_gen in
            Sequence.of_list accounts
            |> Sequence.iter ~f:(fun ({public_key; _} as account) ->
                   let _, location =
                     MT.get_or_create_account_exn mdb public_key account
                   in
                   let location' =
                     MT.location_of_key mdb public_key |> Option.value_exn
                   in
                   assert (location = location') ) )

      let%test_unit "set_inner_hash_at_addr_exn(address,hash); \
                     get_inner_hash_at_addr_exn(address) = hash" =
        let random_hash =
          Hash.hash_account @@ Quickcheck.random_value Account.gen
        in
        Test.with_instance (fun mdb ->
            Quickcheck.test (Direction.gen_var_length_list ~start:1 MT.depth)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun direction ->
                let address = MT.Addr.of_directions direction in
                MT.set_inner_hash_at_addr_exn mdb address random_hash ;
                let result = MT.get_inner_hash_at_addr_exn mdb address in
                assert (Hash.equal result random_hash) ) )

      let random_accounts max_height =
        let num_accounts = 1 lsl max_height in
        Quickcheck.random_value
          (Quickcheck.Generator.list_with_length num_accounts Account.gen)

      let populate_db mdb max_height =
        random_accounts max_height
        |> List.iter ~f:(fun account ->
               let action, location =
                 MT.get_or_create_account_exn mdb
                   (Account.public_key account)
                   account
               in
               match action with
               | `Added -> ()
               | `Existed -> MT.set mdb location account )

      let%test_unit "If the entire database is full, \
                     set_all_accounts_rooted_at_exn(address,accounts);get_all_accounts_rooted_at_exn(address) \
                     = accounts" =
        Test.with_instance (fun mdb ->
            let max_height = Int.min MT.depth 5 in
            populate_db mdb max_height ;
            Quickcheck.test (Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun directions ->
                let address =
                  let offset = MT.depth - max_height in
                  let padding =
                    List.init offset ~f:(fun _ -> Direction.Left)
                  in
                  let padded_directions = List.concat [padding; directions] in
                  MT.Addr.of_directions padded_directions
                in
                let num_accounts = 1 lsl (MT.depth - MT.Addr.depth address) in
                let accounts =
                  Quickcheck.random_value
                    (Quickcheck.Generator.list_with_length num_accounts
                       Account.gen)
                in
                MT.set_all_accounts_rooted_at_exn mdb address accounts ;
                let result = MT.get_all_accounts_rooted_at_exn mdb address in
                assert (List.equal ~equal:Account.equal accounts result) ) )

      let%test_unit "copy" =
        Test.with_instance (fun mdb ->
            let gift = 1 in
            let balance_gen = Int.gen_incl gift (Int.max_value - gift) in
            let public_key = "pk" in
            let balance = Quickcheck.random_value balance_gen in
            let account = Account.create public_key balance in
            let account_location = create_new_account_exn mdb account in
            let mdb_copy = MT.copy mdb in
            let updated_account =
              Account.set_balance account (Balance.of_int (balance + gift))
            in
            MT.set mdb_copy account_location updated_account ;
            let account' = MT.get mdb account_location |> Option.value_exn in
            let updated_account' =
              MT.get mdb_copy account_location |> Option.value_exn
            in
            assert (account' <> updated_account') )

      let%test "get_at_index_exn t (index_of_key_exn t public_key) = account" =
        Test.with_instance (fun mdb ->
            let max_height = Int.min MT.depth 5 in
            let accounts = random_accounts max_height |> dedup_accounts in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn mdb account ) ;
            Sequence.of_list accounts
            |> Sequence.for_all ~f:(fun ({public_key; _} as account) ->
                   let indexed_account =
                     MT.index_of_key_exn mdb public_key
                     |> MT.get_at_index_exn mdb
                   in
                   Account.equal account indexed_account ) )

      let test_subtree_range mdb ~f max_height =
        populate_db mdb max_height ;
        Sequence.range 0 (1 lsl max_height) |> Sequence.iter ~f

      let%test_unit "set_at_index_exn t index  account; get_at_index_exn t \
                     index = account" =
        Test.with_instance (fun mdb ->
            let max_height = Int.min MT.depth 5 in
            test_subtree_range mdb max_height ~f:(fun index ->
                let account = Quickcheck.random_value Account.gen in
                MT.set_at_index_exn mdb index account ;
                let result = MT.get_at_index_exn mdb index in
                assert (account = result) ) )

      let%test_unit "implied_root(account) = root_hash" =
        Test.with_instance (fun mdb ->
            let max_height = Int.min MT.depth 5 in
            populate_db mdb max_height ;
            Quickcheck.test (Direction.gen_list max_height)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun directions ->
                let offset =
                  List.init (MT.depth - max_height) ~f:(fun _ -> Direction.Left)
                in
                let padded_directions = List.concat [offset; directions] in
                let address = MT.Addr.of_directions padded_directions in
                let path = MT.merkle_path_at_addr_exn mdb address in
                let leaf_hash = MT.get_inner_hash_at_addr_exn mdb address in
                let root_hash = MT.merkle_root mdb in
                assert (MT.Path.check_path path leaf_hash root_hash) ) )

      let%test_unit "implied_root(index) = root_hash" =
        Test.with_instance (fun mdb ->
            let max_height = Int.min MT.depth 5 in
            test_subtree_range mdb max_height ~f:(fun index ->
                let path = MT.merkle_path_at_index_exn mdb index in
                let leaf_hash =
                  MT.get_inner_hash_at_addr_exn mdb (MT.Addr.of_int_exn index)
                in
                let root_hash = MT.merkle_root mdb in
                assert (MT.Path.check_path path leaf_hash root_hash) ) )

      let%test_unit "iter" =
        Test.with_instance (fun mdb ->
            let max_height = Int.min MT.depth 5 in
            let accounts = random_accounts max_height |> dedup_accounts in
            List.iter accounts ~f:(fun account ->
                create_new_account_exn mdb account |> ignore ) ;
            assert (accounts = MT.to_list mdb) )

      let%test_unit "Add 2^d accounts (for testing, d is small)" =
        if Test.depth <= 8 then
          Test.with_instance (fun mdb ->
              let gen_balance = Int.gen_incl 1 Int.max_value in
              let accounts =
                List.init (1 lsl Test.depth) ~f:(fun public_key ->
                    Account.create (Int.to_string public_key)
                      (Quickcheck.random_value gen_balance) )
              in
              List.iter accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn mdb account ) ;
              let retrieved_accounts =
                MT.get_all_accounts_rooted_at_exn mdb (MT.Addr.root ())
              in
              assert (List.length accounts = List.length retrieved_accounts) ;
              assert (
                List.equal ~equal:Account.equal accounts retrieved_accounts )
          )
    end

    module Make_db (Depth : sig
      val depth : int
    end) =
    Make (struct
      let depth = Depth.depth

      module Location = Merkle_ledger.Location.Make (Depth)
      module Addr = Location.Addr

      module MT : DB with type location := Location.t =
        Database.Make (Key) (Account) (Hash) (Depth) (Location)
          (In_memory_kvdb)
          (In_memory_sdb)
          (Storage_locations)

      (* TODO: maybe this function should work with dynamic modules *)
      let with_instance (type a) (f : MT.t -> a) =
        let mdb = MT.create () in
        f mdb
    end)

    module Depth_4 = struct
      let depth = 4
    end

    module Mdb_d4 = Make_db (Depth_4)

    module Depth_30 = struct
      let depth = 30
    end

    module Mdb_d30 = Make_db (Depth_30)
  end )
