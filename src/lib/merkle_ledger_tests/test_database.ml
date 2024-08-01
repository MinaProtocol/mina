(* Testing
   -------

   Component: On-disk database
   Subject: Merkle ledger tests for on-disk database
   Invocation: \
     dune exec src/lib/merkle_ledger_tests/main.exe -- test "On-disk"
*)

open Core
open Test_stubs
module Intf = Merkle_ledger.Intf
module Database = Merkle_ledger.Database

module type DB =
  Intf.Ledger.DATABASE
    with type key := Key.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type account := Account.t
     and type root_hash := Hash.t
     and type hash := Hash.t

module type Test_intf = sig
  val depth : int

  module Location : Merkle_ledger.Location_intf.S

  module MT : DB with module Location = Location and module Addr = Location.Addr

  val with_instance : (MT.t -> 'a) -> 'a
end

module Make (Test : Test_intf) = struct
  module MT = Test.MT

  module Location = struct
    include Test.Location

    let testable =
      Alcotest.testable (fun ppf loc -> Sexp.pp ppf (sexp_of_t loc)) equal
  end

  let test_section_name = Printf.sprintf "On-disk db (depth %d)" Test.depth

  let test_stack = Stack.create ()

  let add_test ?(speed = `Quick) name f =
    Alcotest.test_case name speed f |> Stack.push test_stack

  let add_qtest = add_test ~speed:`Slow

  let () =
    add_qtest "getting a non existing account returns None" (fun () ->
        Test.with_instance (fun mdb ->
            Quickcheck.test
              (MT.For_tests.gen_account_location ~ledger_depth:(MT.depth mdb))
              ~f:(fun location ->
                Alcotest.(
                  check (option Account.testable) "account does not exist" None
                    (MT.get mdb location)) ) ) )

  let create_new_account_exn mdb account =
    let public_key = Account.identifier account in
    let action, location =
      MT.get_or_create_account mdb public_key account |> Or_error.ok_exn
    in
    match action with
    | `Existed ->
        failwith "Expected to allocate a new account"
    | `Added ->
        location

  let () =
    add_test "add and retrieve an account" (fun () ->
        Test.with_instance (fun mdb ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_account_exn mdb account in
            Alcotest.check Account.testable "both locations are equal"
              (Option.value_exn (MT.get mdb location))
              account ) )

  let () =
    add_test "accounts are atomic" (fun () ->
        Test.with_instance (fun mdb ->
            let account = Quickcheck.random_value Account.gen in
            let location = create_new_account_exn mdb account in
            MT.set mdb location account ;
            let location' =
              MT.location_of_account mdb (Account.identifier account)
              |> Option.value_exn
            in
            Alcotest.check Location.testable "same locations" location location' ;
            Alcotest.(
              check (option Account.testable) "same accounts at locations"
                (MT.get mdb location) (MT.get mdb location')) ) )

  let dedup_accounts accounts =
    List.dedup_and_sort accounts ~compare:(fun account1 account2 ->
        Account_id.compare
          (Account.identifier account1)
          (Account.identifier account2) )

  let () =
    add_test "length" (fun () ->
        Test.with_instance (fun mdb ->
            let open Quickcheck.Generator in
            let max_accounts = Int.min (1 lsl MT.depth mdb) (1 lsl 5) in
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
            Alcotest.(check int)
              "num accounts is equal to length" num_initial_accounts result ) )

  let () =
    add_test "no update on get_or_create_acount if key already exists"
      (fun () ->
        Test.with_instance (fun mdb ->
            let account_id = Quickcheck.random_value Account_id.gen in
            let balance =
              Quickcheck.random_value ~seed:(`Deterministic "balance 1")
                Balance.gen
            in
            let account = Account.create account_id balance in
            let balance' =
              Quickcheck.random_value ~seed:(`Deterministic "balance 2")
                Balance.gen
            in
            let account' = Account.create account_id balance' in
            let location = create_new_account_exn mdb account in
            let action, location' =
              MT.get_or_create_account mdb account_id account'
              |> Or_error.ok_exn
            in
            Alcotest.(check Location.testable)
              "same location" location location' ;
            assert (match action with `Existed -> true | `Added -> false) ;
            Alcotest.(
              check (neg Account.testable) "same accounts"
                (Option.value_exn (MT.get mdb location))
                account') ) )

  let () =
    add_test "get_or_create_account t account = location_of_account account.key"
      (fun () ->
        Test.with_instance (fun mdb ->
            let accounts_gen =
              let open Quickcheck.Let_syntax in
              let max_height = Int.min (MT.depth mdb) 5 in
              let%bind num_accounts = Int.gen_incl 0 (1 lsl max_height) in
              Quickcheck.Generator.list_with_length num_accounts Account.gen
            in
            let accounts = Quickcheck.random_value accounts_gen in
            Sequence.of_list accounts
            |> Sequence.iter ~f:(fun account ->
                   let account_id = Account.identifier account in
                   let _, location =
                     MT.get_or_create_account mdb account_id account
                     |> Or_error.ok_exn
                   in
                   let location' =
                     MT.location_of_account mdb account_id |> Option.value_exn
                   in
                   Alcotest.(check Location.testable)
                     "identical locations" location location' ) ) )

  let () =
    add_test "get after remove location returns None" (fun () ->
        let account = Account.genval.one () in
        Test.with_instance (fun mdb ->
            let loc = create_new_account_exn mdb account in
            MT.remove_location mdb loc ;
            let acc_opt = MT.get mdb loc in
            Alcotest.(check (option Account.testable))
              "no account at removed location" None acc_opt ) )

  let () =
    add_test "get after remove account returns None" (fun () ->
        let account = Account.genval.one () in
        Test.with_instance (fun mdb ->
            let loc = create_new_account_exn mdb account in
            MT.remove_account mdb account ;
            let acc_opt = MT.get mdb loc in
            Alcotest.(check (option Account.testable))
              "no account at removed location" None acc_opt ) )

  let () =
    add_test "account creation reuses freed location" (fun () ->
        let[@warning "-8"] [ account1; account2; account3 ] =
          Account.genval.many 3
        in
        Test.with_instance (fun mdb ->
            let loc = create_new_account_exn mdb account1 in

            MT.remove_account mdb account1 ;
            let loc2 = create_new_account_exn mdb account2 in
            Alcotest.check Location.testable
              "newly freed location by remove_account is used for allocation"
              loc loc2 ;

            MT.remove_location mdb loc2 ;
            let loc3 = create_new_account_exn mdb account3 in
            Alcotest.check Location.testable
              "newly freed location by remove_location is used for allocation"
              loc loc3 ) )

  let () =
    add_test "allocation reuses freed locations in decreasing order" (fun () ->
        Test.with_instance (fun mdb ->
            let n = min 4 (1 lsl MT.depth mdb) in
            let accounts_1 = Account.genval.many n
            and accounts_2 = Account.genval.many n in
            let locs_1 = List.map accounts_1 ~f:(create_new_account_exn mdb) in
            List.iter locs_1 ~f:(MT.remove_location mdb) ;
            let locs_2 = List.map accounts_2 ~f:(create_new_account_exn mdb) in
            Alcotest.(
              check (list Location.testable)
                "decreasing order and allocated order are the same"
                (List.sort locs_1 ~compare:(Fn.flip Location.compare))
                locs_2) ) )

  let () =
    add_test "num_accounts behaves correctly with removals" (fun () ->
        Test.with_instance (fun mdb ->
            let n = min 4 (1 lsl MT.depth mdb) in
            let accounts = Account.genval.many n in
            let locs = List.map accounts ~f:(create_new_account_exn mdb) in
            List.iteri locs ~f:(fun i loc ->
                MT.remove_location mdb loc ;
                Alcotest.(check int)
                  "num account is correct" (MT.num_accounts mdb)
                  (n - i - 1) ) ) )

  (* Straightforward implemententation of Knuth-Fisher-Yates shuffle *)
  let shuffle_array a =
    for i = Array.length a - 1 downto 1 do
      let tmp = a.(i) in
      let j = Random.int (i + 1) in
      a.(i) <- a.(j) ;
      a.(j) <- tmp
    done

  let shuffle_list l =
    let a = Array.of_list l in
    shuffle_array a ; Array.to_list a

  let () =
    add_test "freed locations are returned in descending order" (fun () ->
        Test.with_instance (fun mdb ->
            let num_accounts = Int.pow 2 (Int.min 5 (MT.depth mdb - 1)) in
            let accounts = Account.genval.many num_accounts in
            let _locs = List.map ~f:(create_new_account_exn mdb) accounts in

            let accounts_to_remove =
              List.take (shuffle_list accounts) (num_accounts / 2)
            in
            List.iter accounts_to_remove ~f:(MT.remove_account mdb) ;
            let freed_locs = MT.get_freed mdb |> Sequence.to_list in

            let sorted_locs =
              (* Sort in increasing order *)
              List.sort ~compare:(Fn.flip Location.compare) freed_locs
            in
            Alcotest.(
              check (list Location.testable)
                "freed locations are sorted in descending order" sorted_locs
                freed_locs) ) )

  let () =
    add_qtest
      "set_inner_hash_at_addr_exn(address,hash); \
       get_inner_hash_at_addr_exn(address) = hash" (fun () ->
        let random_hash =
          Hash.hash_account @@ Quickcheck.random_value Account.gen
        in
        Test.with_instance (fun mdb ->
            Quickcheck.test
              (Direction.gen_var_length_list ~start:1 (MT.depth mdb))
              ~sexp_of:[%sexp_of: Direction.t List.t]
              ~f:(fun direction ->
                let address = MT.Addr.of_directions direction in
                MT.set_inner_hash_at_addr_exn mdb address random_hash ;
                let result = MT.get_inner_hash_at_addr_exn mdb address in
                Alcotest.check Hash.testable "get(set(hash)) = hash" result
                  random_hash ) ) )

  let random_accounts max_height =
    let num_accounts = 1 lsl max_height in
    Quickcheck.random_value
      (Quickcheck.Generator.list_with_length num_accounts Account.gen)

  let populate_db mdb max_height =
    random_accounts max_height
    |> List.iter ~f:(fun account ->
           let action, location =
             MT.get_or_create_account mdb (Account.identifier account) account
             |> Or_error.ok_exn
           in
           match action with
           | `Added ->
               ()
           | `Existed ->
               MT.set mdb location account )

  let () =
    add_qtest
      "set_batch_accounts all_accounts doesn't change already full database "
      (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min depth 5 in
            Quickcheck.test (Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun directions ->
                let address =
                  let offset = depth - max_height in
                  let padding = List.init offset ~f:(fun _ -> Direction.Left) in
                  let padded_directions = List.concat [ padding; directions ] in
                  MT.Addr.of_directions padded_directions
                in
                let old_merkle_root = MT.merkle_root mdb in
                let addresses_and_accounts =
                  MT.get_all_accounts_rooted_at_exn mdb address
                in
                MT.set_batch_accounts mdb addresses_and_accounts ;
                let new_merkle_root = MT.merkle_root mdb in
                Alcotest.check Hash.testable "identical merkle roots"
                  old_merkle_root new_merkle_root ) ) )

  let () =
    add_qtest "set_batch_accounts would change the merkle root" (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min 5 depth in
            populate_db mdb max_height ;
            Quickcheck.test (Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun directions ->
                let address =
                  let offset = depth - max_height in
                  let padding = List.init offset ~f:(fun _ -> Direction.Left) in
                  let padded_directions = List.concat [ padding; directions ] in
                  MT.Addr.of_directions padded_directions
                in
                let num_accounts = 1 lsl (depth - MT.Addr.depth address) in
                let accounts = Account.genval.many num_accounts in

                if not @@ List.is_empty accounts then
                  let addresses =
                    List.rev
                    @@ MT.Addr.Range.fold
                         (MT.Addr.Range.subtree_range ~ledger_depth:depth
                            address ) ~init:[] ~f:(fun address addresses ->
                           address :: addresses )
                  in
                  let new_addresses_and_accounts =
                    List.zip_exn addresses accounts
                  in
                  let old_addresses_and_accounts =
                    MT.get_all_accounts_rooted_at_exn mdb address
                  in
                  (* TODO: After we do not generate duplicate accounts anymore,
                     this should get removed *)
                  if
                    not
                    @@ List.equal
                         (fun (addr1, account1) (addr2, account2) ->
                           MT.Addr.equal addr1 addr2
                           && Account.equal account1 account2 )
                         old_addresses_and_accounts new_addresses_and_accounts
                  then (
                    let old_merkle_root = MT.merkle_root mdb in
                    MT.set_batch_accounts mdb new_addresses_and_accounts ;
                    let new_merkle_root = MT.merkle_root mdb in
                    Alcotest.(check (neg Hash.testable))
                      "merkle roots are different" old_merkle_root
                      new_merkle_root ) ) ) )

  let () =
    add_test "key by key account retrieval after set_batch_accounts works"
      (fun () ->
        Test.with_instance (fun mdb ->
            (* We want to add accounts to a nonempty database *)
            let max_height = Int.min (MT.depth mdb - 1) 3 in
            populate_db mdb max_height ;
            let accounts = random_accounts max_height |> dedup_accounts in
            Alcotest.(check bool "db is compact" true (MT.is_compact mdb)) ;
            let (last_location : MT.Location.t) =
              MT.max_filled mdb |> Option.value_exn
            in
            let accounts_with_addresses =
              List.folding_map accounts ~init:last_location
                ~f:(fun prev_location account ->
                  let location =
                    Test.Location.next prev_location |> Option.value_exn
                  in
                  (location, (location |> Test.Location.to_path_exn, account)) )
            in
            MT.set_batch_accounts mdb accounts_with_addresses ;
            List.iter accounts ~f:(fun account ->
                let aid = Account.identifier account in
                let location =
                  MT.location_of_account mdb aid |> Option.value_exn
                in
                let queried_account = MT.get mdb location |> Option.value_exn in
                Alcotest.(check Account.testable)
                  "equal accounts" queried_account account ) ;
            let to_int =
              Fn.compose MT.Location.Addr.to_int MT.Location.to_path_exn
            in
            let expected_last_location =
              (MT.Location.Addr.to_int @@ MT.Location.to_path_exn last_location)
              + List.length accounts
            in
            let actual_last_location =
              to_int (MT.max_filled mdb |> Option.value_exn)
            in
            Alcotest.(check int)
              "location is the same" expected_last_location actual_last_location ) )

  let () =
    add_qtest
      "when database is full, \
       set_all_accounts_rooted_at_exn(address,accounts);get_all_accounts_rooted_at_exn(address) \
       = accounts " (fun () ->
        Test.with_instance (fun mdb ->
            let max_height = Int.min (MT.depth mdb) 5 in
            populate_db mdb max_height ;
            Quickcheck.test (Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun directions ->
                let address =
                  let offset = MT.depth mdb - max_height in
                  let padding = List.init offset ~f:(fun _ -> Direction.Left) in
                  let padded_directions = List.concat [ padding; directions ] in
                  MT.Addr.of_directions padded_directions
                in
                let num_accounts =
                  1 lsl (MT.depth mdb - MT.Addr.depth address)
                in
                let accounts =
                  Quickcheck.random_value
                    (Quickcheck.Generator.list_with_length num_accounts
                       Account.gen )
                in
                MT.set_all_accounts_rooted_at_exn mdb address accounts ;
                let result =
                  List.map ~f:snd
                  @@ MT.get_all_accounts_rooted_at_exn mdb address
                in
                Alcotest.(check (list Account.testable))
                  "identical accounts" accounts result ) ) )

  let () =
    add_test "create_empty doesn't modify the hash" (fun () ->
        Test.with_instance (fun ledger ->
            let open MT in
            let key = Quickcheck.random_value Account_id.gen in
            let start_hash = merkle_root ledger in
            match
              get_or_create_account ledger key Account.empty |> Or_error.ok_exn
            with
            | `Existed, _ ->
                failwith
                  "create_empty with empty ledger somehow already has that key?"
            | `Added, _ ->
                Alcotest.check Hash.testable "hash hasn't changed" start_hash
                  (merkle_root ledger) ) )

  let () =
    add_test "get_at_index_exn t (index_of_account_exn t public_key) = account"
      (fun () ->
        Test.with_instance (fun mdb ->
            let max_height = Int.min (MT.depth mdb) 5 in
            let accounts = random_accounts max_height |> dedup_accounts in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn mdb account ) ;

            List.iter accounts ~f:(fun account ->
                let indexed_account =
                  MT.index_of_account_exn mdb (Account.identifier account)
                  |> MT.get_at_index_exn mdb
                in
                Alcotest.(check Account.testable)
                  "identical accounts" account indexed_account ) ) )

  let test_subtree_range mdb ~f max_height =
    populate_db mdb max_height ;
    Sequence.range 0 (1 lsl max_height) |> Sequence.iter ~f

  let () =
    add_test
      "set_at_index_exn t index  account; get_at_index_exn t index = account"
      (fun () ->
        Test.with_instance (fun mdb ->
            let max_height = Int.min (MT.depth mdb) 5 in
            test_subtree_range mdb max_height ~f:(fun index ->
                let account = Quickcheck.random_value Account.gen in
                MT.set_at_index_exn mdb index account ;
                let result = MT.get_at_index_exn mdb index in
                Alcotest.(check Account.testable)
                  "identical accounts" account result ) ) )

  let () =
    add_qtest "implied_root(account) = root_hash" (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min depth 5 in
            populate_db mdb max_height ;
            Quickcheck.test (Direction.gen_list max_height)
              ~sexp_of:[%sexp_of: Direction.t List.t] ~f:(fun directions ->
                let offset =
                  List.init (depth - max_height) ~f:(fun _ -> Direction.Left)
                in
                let padded_directions = List.concat [ offset; directions ] in
                let address = MT.Addr.of_directions padded_directions in
                let path = MT.merkle_path_at_addr_exn mdb address in
                let leaf_hash = MT.get_inner_hash_at_addr_exn mdb address in
                let root_hash = MT.merkle_root mdb in
                assert (MT.Path.check_path path leaf_hash root_hash) ) ) )

  let () =
    add_test "implied_root(index) = root_hash" (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min depth 5 in
            test_subtree_range mdb max_height ~f:(fun index ->
                let path = MT.merkle_path_at_index_exn mdb index in
                let leaf_hash =
                  MT.get_inner_hash_at_addr_exn mdb
                    (MT.Addr.of_int_exn ~ledger_depth:depth index)
                in
                let root_hash = MT.merkle_root mdb in
                assert (MT.Path.check_path path leaf_hash root_hash) ) ) )

  let () =
    add_test "iter" (fun () ->
        Test.with_instance (fun mdb ->
            let max_height = Int.min (MT.depth mdb) 5 in
            let accounts = random_accounts max_height |> dedup_accounts in
            List.iter accounts ~f:(fun account ->
                ignore (create_new_account_exn mdb account : Test.Location.t) ) ;
            let expect = MT.to_list_sequential mdb in
            Alcotest.(
              check (list Account.testable) "accounts in db are the one put in"
                accounts expect) ) )

  let () =
    if Test.depth <= 8 then
      (* d needs to be small enough *)
      let name = Printf.sprintf "add 2^%d accounts" Test.depth in
      add_test name (fun () ->
          let num_accounts = 1 lsl Test.depth in
          let account_ids = Account_id.genval.many num_accounts in
          let balances = Balance.genval.many num_accounts in
          let accounts = List.map2_exn account_ids balances ~f:Account.create in
          Test.with_instance (fun mdb ->
              List.iter accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn mdb account ) ;
              let retrieved_accounts =
                List.map ~f:snd
                @@ MT.get_all_accounts_rooted_at_exn mdb (MT.Addr.root ())
              in
              Alcotest.(check (list Account.testable))
                "identical accounts" accounts retrieved_accounts ) )

  let () =
    add_test "fold over account balances" (fun () ->
        Test.with_instance (fun mdb ->
            let num_accounts = 5 in
            let account_ids = Account_id.genval.many num_accounts in
            let balances = Balance.genval.many num_accounts in
            let total =
              List.fold balances ~init:0 ~f:(fun accum balance ->
                  Balance.to_nanomina_int balance + accum )
            in
            let accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn mdb account ) ;
            let retrieved_total =
              MT.foldi mdb ~init:0 ~f:(fun _addr total account ->
                  Balance.to_nanomina_int (Account.balance account) + total )
            in
            Alcotest.(check int) "retrieved same total" total retrieved_total ) )

  let () =
    add_test "fold_until over account balances" (fun () ->
        Async_unix.Thread_safe.block_on_async_exn (fun () ->
            Test.with_instance (fun mdb ->
                let num_accounts = 5 in
                let some_num = 3 in
                let account_ids = Account_id.genval.many num_accounts in
                let some_account_ids = List.take account_ids some_num in
                let last_account_id = List.hd_exn (List.rev some_account_ids) in
                let balances = Balance.genval.many num_accounts in
                let some_balances = List.take balances some_num in
                let total =
                  List.fold some_balances ~init:0 ~f:(fun accum balance ->
                      Balance.to_int balance + accum )
                in
                let accounts =
                  List.map2_exn account_ids balances ~f:Account.create
                in
                List.iter accounts ~f:(fun account ->
                    ignore @@ create_new_account_exn mdb account ) ;
                (* stop folding on last_account_id, sum of balances in accounts should be same as some_balances *)
                let%map.Async.Deferred retrieved_total =
                  MT.fold_until mdb ~init:0
                    ~f:(fun total account ->
                      let current_balance = Account.balance account in
                      let current_account_id = Account.identifier account in
                      let new_total = Balance.to_int current_balance + total in
                      if Account_id.equal current_account_id last_account_id
                      then Stop new_total
                      else Continue new_total )
                    ~finish:(fun total -> total)
                in
                Alcotest.(check int) "same total" total retrieved_total ) ) )

  let tests =
    let actual_tests = Stack.fold test_stack ~f:(fun l t -> t :: l) ~init:[] in
    (test_section_name, actual_tests)
end

module Make_db (Depth : sig
  val depth : int
end) =
Make (struct
  let depth = Depth.depth

  module Location = Merkle_ledger.Location.T

  module Location_binable = struct
    module Arg = struct
      type t = Location.t =
        | Generic of Merkle_ledger.Location.Bigstring.Stable.Latest.t
        | Account of Location.Addr.Stable.Latest.t
        | Hash of Location.Addr.Stable.Latest.t
      [@@deriving bin_io_unversioned, hash, sexp, compare]
    end

    type t = Arg.t =
      | Generic of Merkle_ledger.Location.Bigstring.Stable.Latest.t
      | Account of Location.Addr.Stable.Latest.t
      | Hash of Location.Addr.Stable.Latest.t
    [@@deriving hash, sexp, compare]

    include Hashable.Make_binable (Arg) [@@deriving sexp, compare, hash, yojson]
  end

  module Inputs = struct
    include Test_stubs.Base_inputs
    module Location = Location
    module Location_binable = Location_binable
    module Kvdb = In_memory_kvdb
    module Storage_locations = Storage_locations
  end

  module MT = Database.Make (Inputs)

  (* TODO: maybe this function should work with dynamic modules *)
  let with_instance (f : MT.t -> 'a) =
    let mdb = MT.create ~depth () in
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

let tests = [ Mdb_d4.tests; Mdb_d30.tests ]
