(* Testing
   -------

   Component: In memory database
   Subject: Merkle ledger tests for in-memory database
   Invocation: \
     dune exec src/lib/merkle_ledger_tests/main.exe -- test "In-memory db"
*)

open Core
open Test_stubs
module Intf = Merkle_ledger.Intf
module Database = Merkle_ledger.Database
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

module type Account_Db =
  Merkle_ledger.Intf.Ledger.DATABASE
    with module Location = Location
    with module Addr = Location.Addr
    with type root_hash := Md5.t
     and type hash := Md5.t
     and type key := Key.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id_set := Account_id.Set.t
     and type account_id := Account_id.t

module type DB = Account_Db with type account := Account.t

module Make_inputs
    (Account : Merkle_ledger.Intf.Account
                 with type account_id := Account_id.t
                  and type token_id := Token_id.t
                  and type balance := Balance.t)
    (Hash : Merkle_ledger.Intf.Hash with type account := Account.t) =
struct
  include Test_stubs.Make_base_inputs (Account) (Hash)
  module Location = Location
  module Addr = Location.Addr
  module Location_binable = Location_binable
  module Kvdb = In_memory_kvdb
  module Storage_locations = Storage_locations
end

module type Test_intf = sig
  val depth : int

  module MT : DB

  val with_instance : (MT.t -> 'a) -> 'a
end

module Make (Test : Test_intf) = struct
  module MT = Test.MT

  let test_section_name = Printf.sprintf "In-memory db (depth %d)" Test.depth

  let test_stack = Stack.create ()

  let add_test ?(speed = `Quick) name f =
    Alcotest.test_case name speed f |> Stack.push test_stack

  let test_non_existing_account_is_none () =
    Test.with_instance (fun mdb ->
        Quickcheck.test
          (MT.For_tests.gen_account_location ~ledger_depth:(MT.depth mdb))
          ~f:(fun location -> assert (Option.is_none (MT.get mdb location))) )

  let () =
    add_test "getting a non existing account returns None"
      test_non_existing_account_is_none

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
            [%test_eq: Account.t]
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
            assert (
              MT.Location.equal location location'
              &&
              match (MT.get mdb location, MT.get mdb location') with
              | Some acct, Some acct' ->
                  Account.equal acct acct'
              | _, _ ->
                  false ) ) )

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
            [%test_eq: int] result num_initial_accounts ) )

  let () =
    add_test "no update on get_or_create_acount if key already exists"
      (fun () ->
        Test.with_instance (fun mdb ->
            let account_id = Quickcheck.random_value Account_id.gen in
            let balance =
              Quickcheck.random_value ~seed:(`Deterministic "balance 1")
                Balance.gen
            in
            let T = Account_id.eq in
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
            assert (
              [%equal: Location.t] location location'
              && (match action with `Existed -> true | `Added -> false)
              && not
                   (Mina_base.Account.equal
                      (Option.value_exn (MT.get mdb location))
                      account' ) ) ) )

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
                   assert ([%equal: Location.t] location location') ) ) )

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
    add_test
      "set_batch_accounts all_accounts doesn't change already full database "
      (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min depth 5 in
            Quickcheck.test
              (Mina_stdlib.Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Mina_stdlib.Direction.t List.t]
              ~f:(fun directions ->
                let address =
                  let offset = depth - max_height in
                  let padding =
                    List.init offset ~f:(fun _ -> Mina_stdlib.Direction.Left)
                  in
                  let padded_directions = List.concat [ padding; directions ] in
                  MT.Addr.of_directions padded_directions
                in
                let old_merkle_root = MT.merkle_root mdb in
                let addresses_and_accounts =
                  MT.get_all_accounts_rooted_at_exn mdb address
                in
                MT.set_batch_accounts mdb addresses_and_accounts ;
                let new_merkle_root = MT.merkle_root mdb in
                assert (Md5.equal old_merkle_root new_merkle_root) ) ) )

  let () =
    add_test "set_batch_accounts would change the merkle root" (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min 5 depth in
            populate_db mdb max_height ;
            Quickcheck.test
              (Mina_stdlib.Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Mina_stdlib.Direction.t List.t]
              ~f:(fun directions ->
                let address =
                  let offset = depth - max_height in
                  let padding =
                    List.init offset ~f:(fun _ -> Mina_stdlib.Direction.Left)
                  in
                  let padded_directions = List.concat [ padding; directions ] in
                  MT.Addr.of_directions padded_directions
                in
                let num_accounts = 1 lsl (depth - MT.Addr.depth address) in
                let accounts =
                  Quickcheck.random_value
                    (Quickcheck.Generator.list_with_length num_accounts
                       Account.gen )
                in
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
                    assert (not @@ Md5.equal old_merkle_root new_merkle_root) ) ) ) )

  let () =
    add_test "key by key account retrieval after set_batch_accounts works"
      (fun () ->
        Test.with_instance (fun mdb ->
            (* We want to add accounts to a nonempty database *)
            let max_height = Int.min (MT.depth mdb - 1) 3 in
            populate_db mdb max_height ;
            let accounts = random_accounts max_height |> dedup_accounts in
            let (last_location : MT.Location.t) =
              MT.last_filled mdb |> Option.value_exn
            in
            let accounts_with_addresses =
              List.folding_map accounts ~init:last_location
                ~f:(fun prev_location account ->
                  let location =
                    Location.next prev_location |> Option.value_exn
                  in
                  (location, (location |> Location.to_path_exn, account)) )
            in
            MT.set_batch_accounts mdb accounts_with_addresses ;
            List.iter accounts ~f:(fun account ->
                let aid = Account.identifier account in
                let location =
                  MT.location_of_account mdb aid |> Option.value_exn
                in
                let queried_account = MT.get mdb location |> Option.value_exn in
                assert (Account.equal queried_account account) ) ;
            let to_int =
              Fn.compose MT.Location.Addr.to_int MT.Location.to_path_exn
            in
            let expected_last_location =
              (MT.Location.Addr.to_int @@ MT.Location.to_path_exn last_location)
              + List.length accounts
            in
            let actual_last_location =
              to_int (MT.last_filled mdb |> Option.value_exn)
            in
            [%test_result: int] ~expect:expected_last_location
              actual_last_location
              ~message:
                (sprintf "(expected_location: %i) (actual_location: %i)"
                   expected_last_location actual_last_location ) ) )

  let () =
    add_test
      "when database is full, \
       set_all_accounts_rooted_at_exn(address,accounts);get_all_accounts_rooted_at_exn(address) \
       = accounts " (fun () ->
        Test.with_instance (fun mdb ->
            let max_height = Int.min (MT.depth mdb) 5 in
            populate_db mdb max_height ;
            Quickcheck.test
              (Mina_stdlib.Direction.gen_var_length_list max_height)
              ~sexp_of:[%sexp_of: Mina_stdlib.Direction.t List.t]
              ~f:(fun directions ->
                let address =
                  let offset = MT.depth mdb - max_height in
                  let padding =
                    List.init offset ~f:(fun _ -> Mina_stdlib.Direction.Left)
                  in
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
                assert (List.equal Account.equal accounts result) ) ) )

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
                [%test_eq: Md5.t] start_hash (merkle_root ledger) ) )

  let () =
    add_test "get_at_index_exn t (index_of_account_exn t public_key) = account"
      (fun () ->
        Test.with_instance (fun mdb ->
            let max_height = Int.min (MT.depth mdb) 5 in
            let accounts = random_accounts max_height |> dedup_accounts in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn mdb account ) ;
            assert (
              Sequence.of_list accounts
              |> Sequence.for_all ~f:(fun account ->
                     let indexed_account =
                       MT.index_of_account_exn mdb (Account.identifier account)
                       |> MT.get_at_index_exn mdb
                     in
                     Account.equal account indexed_account ) ) ) )

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
                assert (Account.equal account result) ) ) )

  let () =
    add_test "implied_root(account) = root_hash" (fun () ->
        Test.with_instance (fun mdb ->
            let depth = MT.depth mdb in
            let max_height = Int.min depth 5 in
            populate_db mdb max_height ;
            Quickcheck.test (Mina_stdlib.Direction.gen_list max_height)
              ~sexp_of:[%sexp_of: Mina_stdlib.Direction.t List.t]
              ~f:(fun directions ->
                let offset =
                  List.init (depth - max_height) ~f:(fun _ ->
                      Mina_stdlib.Direction.Left )
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
                ignore (create_new_account_exn mdb account : Location.t) ) ;
            let expect = MT.to_list_sequential mdb in
            [%test_result: Account.t list] accounts ~expect ) )

  let () =
    if Test.depth <= 8 then
      (* d needs to be small enough *)
      let name = Printf.sprintf "add 2^%d accounts" Test.depth in
      add_test name (fun () ->
          let num_accounts = 1 lsl Test.depth in
          let account_ids = Account_id.gen_accounts num_accounts in
          let balances =
            Quickcheck.random_value
              (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
          in
          let T = Account_id.eq in
          let accounts = List.map2_exn account_ids balances ~f:Account.create in
          Test.with_instance (fun mdb ->
              List.iter accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn mdb account ) ;
              let retrieved_accounts =
                List.map ~f:snd
                @@ MT.get_all_accounts_rooted_at_exn mdb (MT.Addr.root ())
              in
              assert (
                Stdlib.List.compare_lengths accounts retrieved_accounts = 0 ) ;
              assert (List.equal Account.equal accounts retrieved_accounts) ) )

  let () =
    add_test "fold over account balances" (fun () ->
        Test.with_instance (fun mdb ->
            let num_accounts = 5 in
            let account_ids = Account_id.gen_accounts num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let total =
              List.fold balances ~init:0 ~f:(fun accum balance ->
                  Balance.to_nanomina_int balance + accum )
            in
            let T = Account_id.eq in
            let accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn mdb account ) ;
            let retrieved_total =
              MT.foldi mdb ~init:0 ~f:(fun _addr total account ->
                  Balance.to_nanomina_int (Account.balance account) + total )
            in
            assert (Int.equal retrieved_total total) ) )

  let () =
    add_test "fold_until over account balances" (fun () ->
        Async_unix.Thread_safe.block_on_async_exn (fun () ->
            Test.with_instance (fun mdb ->
                let num_accounts = 5 in
                let some_num = 3 in
                let account_ids = Account_id.gen_accounts num_accounts in
                let some_account_ids = List.take account_ids some_num in
                let last_account_id = List.hd_exn (List.rev some_account_ids) in
                let balances =
                  Quickcheck.random_value
                    (Quickcheck.Generator.list_with_length num_accounts
                       Balance.gen )
                in
                let some_balances = List.take balances some_num in
                let total =
                  List.fold some_balances ~init:0 ~f:(fun accum balance ->
                      Balance.to_int balance + accum )
                in
                let T = Account_id.eq in
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
                assert (Int.equal retrieved_total total) ) ) )

  let tests =
    let actual_tests = Stack.fold test_stack ~f:(fun l t -> t :: l) ~init:[] in
    (test_section_name, actual_tests)
end

module Inputs = Make_inputs (Account) (Hash)

module Make_db (Depth : sig
  val depth : int
end) =
Make (struct
  let depth = Depth.depth

  module MT = Database.Make (Inputs)

  (* TODO: maybe this function should work with dynamic modules *)
  let with_instance (f : MT.t -> 'a) =
    let mdb = MT.create ~depth () in
    f mdb
end)

module Depth_4 = struct
  module Account = Test_stubs.Account
  module Hash = Test_stubs.Hash

  let depth = 4
end

module Mdb_d4 = Make_db (Depth_4)

module Depth_30 = struct
  module Account = Test_stubs.Account
  module Hash = Test_stubs.Hash

  let depth = 30
end

module Mdb_d30 = Make_db (Depth_30)

let tests = [ Mdb_d4.tests; Mdb_d30.tests ]
