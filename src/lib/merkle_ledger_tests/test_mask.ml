(* Testing
   -------

   Component: Merkle masks
   Subject: Test Merkle mask connected to underlying Merkle tree
   Invocation: \
      dune exec src/lib/merkle_ledger_tests/main.exe -- \
      test "Mask with underlying Merkle tree"
*)

open Core
open Test_stubs
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
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t

  module Mask :
    Merkle_mask.Masking_merkle_tree_intf.S
      with module Location = Location
       and module Attached.Addr = Location.Addr
      with type account := Account.t
       and type location := Location.t
       and type hash := Hash.t
       and type parent := Base.t
       and type key := Key.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t

  module Maskable :
    Merkle_mask.Maskable_merkle_tree_intf.S
      with module Location = Location
       and module Addr = Location.Addr
      with type account := Account.t
       and type root_hash := Hash.t
       and type hash := Hash.t
       and type unattached_mask := Mask.t
       and type attached_mask := Mask.Attached.t
       and type t := Base.t
       and type key := Key.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t

  val with_instances : (Base.t -> Mask.t -> 'a) -> 'a

  (** Here we provide a base ledger and two layers of attached masks
          * one ontop another *)
  val with_chain :
       (   Base.t (* base ledger *)
        -> mask:(Mask.Attached.t * Base.t) lazy_t
        -> (* first mask on top of base ledger *)
           mask2:Mask.Attached.t lazy_t
        -> (* second mask on top of the first mask *)
           'a )
    -> 'a
end

module Make (Test : Test_intf) = struct
  module Maskable = Test.Maskable
  module Mask = Test.Mask

  let directions =
    let rec add_direction count b accum =
      if count >= Test.depth then accum
      else
        let dir =
          if b then Mina_stdlib.Direction.Right else Mina_stdlib.Direction.Left
        in
        add_direction (count + 1) (not b) (dir :: accum)
    in
    add_direction 0 false []

  let test_section_name =
    Printf.sprintf "Mask with underlying Merkle tree (depth:%d)" Test.depth

  let test_stack = Stack.create ()

  let add_test name f_test =
    Alcotest.test_case name `Quick f_test |> Stack.push test_stack

  let dummy_address = Test.Location.Addr.of_directions directions

  let dummy_location = Test.Location.Account dummy_address

  let dummy_account =
    let account = Quickcheck.random_value Account.gen in
    { account with token_id = Token_id.default }

  let create_new_account_exn mask account =
    let public_key = Account.identifier account in
    let action, location =
      Mask.Attached.get_or_create_account mask public_key account
      |> Or_error.ok_exn
    in
    match action with
    | `Existed ->
        failwith "Expected to allocate a new account"
    | `Added ->
        location

  let create_existing_account_exn mask account =
    let account_id = Account.identifier account in
    let action, location =
      Mask.Attached.get_or_create_account mask account_id account
      |> Or_error.ok_exn
    in
    match action with
    | `Existed ->
        Mask.Attached.set mask location account ;
        location
    | `Added ->
        failwith "Expected to re-use an existing account"

  let parent_create_new_account_exn parent account =
    let public_key = Account.identifier account in
    let action, location =
      Maskable.get_or_create_account parent public_key account
      |> Or_error.ok_exn
    in
    match action with
    | `Existed ->
        failwith "Expected to allocate a new account"
    | `Added ->
        location

  let () =
    add_test "parent, mask agree on set" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            Maskable.set maskable dummy_location dummy_account ;
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            let maskable_result = Maskable.get maskable dummy_location in
            let mask_result = Mask.Attached.get attached_mask dummy_location in
            assert (Option.is_some maskable_result) ;
            assert (Option.is_some mask_result) ;
            let maskable_account = Option.value_exn maskable_result in
            let mask_account = Option.value_exn mask_result in
            [%test_eq: Account.t] maskable_account mask_account ) )

  let compare_maskable_mask_hashes ?(check_hash_in_mask = false) maskable mask
      addr =
    let root = Mask.Attached.Addr.root () in
    let rec test_hashes_at_address addr =
      ( (not check_hash_in_mask)
      || Mask.Attached.For_testing.address_in_mask mask addr )
      &&
      let maybe_mask_hash = Mask.Attached.get_hash mask addr in
      Option.is_some maybe_mask_hash
      &&
      let mask_hash = Option.value_exn maybe_mask_hash in
      let maskable_hash = Maskable.get_inner_hash_at_addr_exn maskable addr in
      Hash.equal mask_hash maskable_hash
      &&
      if Mask.Addr.equal root addr then true
      else test_hashes_at_address (Mask.Attached.Addr.parent_exn addr)
    in
    test_hashes_at_address addr

  let () =
    add_test "parent, mask agree on hashes; set in both mask and parent"
      (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set in both parent and mask *)
            Maskable.set maskable dummy_location dummy_account ;
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* verify all hashes to root are same in mask and parent *)
            assert (
              compare_maskable_mask_hashes ~check_hash_in_mask:true maskable
                attached_mask dummy_address ) ) )

  let () =
    add_test "parent, mask agree on hashes; set only in parent" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set only in parent *)
            Maskable.set maskable dummy_location dummy_account ;
            (* verify all hashes to root are same in mask and parent *)
            assert (
              compare_maskable_mask_hashes maskable attached_mask dummy_address ) ) )

  let () =
    add_test "mask prune after parent notification" (fun () ->
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
              assert (
                not
                  (Mask.Attached.For_testing.location_in_mask attached_mask
                     dummy_location ) ) )
            else assert false ) )

  let () =
    add_test "commit puts mask contents in parent, flushes mask" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            (* set to mask *)
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* verify account is in mask *)
            assert (
              Mask.Attached.For_testing.location_in_mask attached_mask
                dummy_location ) ;
            Mask.Attached.commit attached_mask ;
            assert (
              (* verify account no longer in mask but is in parent *)
              not
                (Mask.Attached.For_testing.location_in_mask attached_mask
                   dummy_location ) ) ;
            assert (Option.is_some (Maskable.get maskable dummy_location)) ) )

  let () =
    add_test "commit at layer2, dumps to layer1, not in base" (fun () ->
        Test.with_chain (fun base ~mask:m1_lazy ~mask2:m2_lazy ->
            let m2 = Lazy.force m2_lazy in
            let m1, _ = Lazy.force m1_lazy in
            Mask.Attached.set m2 dummy_location dummy_account ;
            (* verify account is in the layer2 mask *)
            assert (Mask.Attached.For_testing.location_in_mask m2 dummy_location) ;
            Mask.Attached.commit m2 ;
            (* account is no longer in layer2 *)
            assert (
              not (Mask.Attached.For_testing.location_in_mask m2 dummy_location) ) ;
            (* account is still not in base *)
            assert (Option.is_none @@ Maskable.get base dummy_location) ;
            (* account is present in layer1 *)
            assert (Mask.Attached.For_testing.location_in_mask m1 dummy_location) ) )

  let () =
    add_test "register and unregister mask" (fun () ->
        Test.with_instances (fun maskable mask ->
            let (attached_mask : Mask.Attached.t) =
              Maskable.register_mask maskable mask
            in
            let _m = Maskable.unregister_mask_exn ~loc:__LOC__ attached_mask in
            () ) )

  let () =
    add_test "mask and parent agree on Merkle path" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            Mask.Attached.set attached_mask dummy_location dummy_account ;
            (* set affects hashes along the path P from location to the root, while the Merkle path for the location
                   contains the siblings of P elements; to observe a hash in the Merkle path changed by the set, choose an
                   address that is a sibling of an element in P; the Merkle path for that address will include a P element
            *)
            let address =
              dummy_address |> Maskable.Addr.parent_exn |> Maskable.Addr.sibling
            in
            let mask_merkle_path =
              Mask.Attached.merkle_path_at_addr_exn attached_mask address
            in
            Maskable.set maskable dummy_location dummy_account ;
            let maskable_merkle_path =
              Maskable.merkle_path_at_addr_exn maskable address
            in
            assert (
              Mask.Attached.Path.equal mask_merkle_path maskable_merkle_path ) ) )

  let () =
    add_test "mask and parent agree on Merkle root before set" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let mask_merkle_root = Mask.Attached.merkle_root attached_mask in
            let maskable_merkle_root = Maskable.merkle_root maskable in
            [%test_eq: Hash.t] mask_merkle_root maskable_merkle_root ) )

  let () =
    add_test "mask and parent agree on Merkle root after set" (fun () ->
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
            assert (
              Mask.Attached.For_testing.address_in_mask attached_mask
                (Mask.Addr.root ())
              && Hash.equal mask_merkle_root maskable_merkle_root ) ) )

  let () =
    if Test.depth <= 8 then
      add_test "add and retrieve a block of accounts" (fun () ->
          (* see similar test in test_database *)
          Test.with_instances (fun maskable mask ->
              let attached_mask = Maskable.register_mask maskable mask in
              let num_accounts = 1 lsl Test.depth in
              let gen_values gen =
                Quickcheck.random_value
                  (Quickcheck.Generator.list_with_length num_accounts gen)
              in
              let account_ids = Account_id.gen_accounts num_accounts in
              let balances = gen_values Balance.gen in
              let T = Account_id.eq in
              let accounts =
                List.map2_exn account_ids balances ~f:(fun public_key balance ->
                    Account.create public_key balance )
              in
              List.iter accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn attached_mask account ) ;
              let retrieved_accounts =
                List.map ~f:snd
                @@ Mask.Attached.get_all_accounts_rooted_at_exn attached_mask
                     (Mask.Addr.root ())
              in
              assert (
                Stdlib.List.compare_lengths accounts retrieved_accounts = 0 ) ;
              assert (List.equal Account.equal accounts retrieved_accounts) ) )

  let () =
    if Test.depth <= 8 then
      add_test
        "get_all_accounts should preserve the ordering of accounts by location \
         with noncontiguous updates of accounts on the mask" (fun () ->
          (* see similar test in test_database *)
          Test.with_chain (fun _ ~mask:mask1_lazy ~mask2:mask2_lazy ->
              let mask1, _ = Lazy.force mask1_lazy in
              let num_accounts = 1 lsl Test.depth in
              let gen_values gen list_length =
                Quickcheck.random_value
                  (Quickcheck.Generator.list_with_length list_length gen)
              in
              let account_ids = Account_id.gen_accounts num_accounts in
              let balances = gen_values Balance.gen num_accounts in
              let T = Account_id.eq in
              let base_accounts =
                List.map2_exn account_ids balances ~f:Account.create
              in
              List.iter base_accounts ~f:(fun account ->
                  ignore @@ create_new_account_exn mask1 account ) ;
              let num_subset =
                Quickcheck.random_value (Int.gen_incl 3 num_accounts)
              in
              let subset_indices, subset_accounts =
                List.permute
                  (List.mapi base_accounts ~f:(fun index account ->
                       (index, account) ) )
                |> (Fn.flip List.take) num_subset
                |> List.unzip
              in
              let subset_balances = gen_values Balance.gen num_subset in
              let mask2 = Lazy.force mask2_lazy in
              let subset_updated_accounts =
                List.map2_exn subset_accounts subset_balances
                  ~f:(fun account balance ->
                    let updated_account = { account with balance } in
                    ignore
                      ( create_existing_account_exn mask2 updated_account
                        : Test.Location.t ) ;
                    updated_account )
              in
              let updated_accounts_map =
                Int.Map.of_alist_exn
                  (List.zip_exn subset_indices subset_updated_accounts)
              in
              let expected_accounts =
                List.mapi base_accounts ~f:(fun index base_account ->
                    Option.value
                      (Map.find updated_accounts_map index)
                      ~default:base_account )
              in
              let retrieved_accounts =
                List.map ~f:snd
                @@ Mask.Attached.get_all_accounts_rooted_at_exn mask2
                     (Mask.Addr.root ())
              in
              assert (
                Stdlib.List.compare_lengths base_accounts retrieved_accounts = 0 ) ;
              assert (
                List.equal Account.equal expected_accounts retrieved_accounts ) ) )

  let () =
    add_test "fold of addition over account balances in parent and mask"
      (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts_parent = 5 in
            let num_accounts_mask = 5 in
            let num_accounts = num_accounts_parent + num_accounts_mask in
            let account_ids = Account_id.gen_accounts num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let T = Account_id.eq in
            let accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            let total =
              List.fold balances ~init:0 ~f:(fun accum balance ->
                  Balance.to_nanomina_int balance + accum )
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
                  Balance.to_nanomina_int (Account.balance account) + total )
            in
            assert (Int.equal retrieved_total total) ) )

  let () =
    add_test "masking in to_list" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts = 10 in
            let account_ids = Account_id.gen_accounts num_accounts in
            (* parent balances all non-zero *)
            let balances =
              List.init num_accounts ~f:(fun n ->
                  Balance.of_nanomina_int_exn (n + 1) )
            in
            let T = Account_id.eq in
            let parent_accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            (* add accounts to parent *)
            List.iter parent_accounts ~f:(fun account ->
                ignore @@ parent_create_new_account_exn maskable account ) ;
            (* all accounts in parent to_list *)
            let parent_list = Maskable.to_list_sequential maskable in
            let zero_balance account =
              Account.update_balance account Balance.zero
            in
            (* put same accounts in mask, but with zero balance *)
            let mask_accounts = List.map parent_accounts ~f:zero_balance in
            List.iter mask_accounts ~f:(fun account ->
                ignore @@ create_existing_account_exn attached_mask account ) ;
            let mask_list = Mask.Attached.to_list_sequential attached_mask in
            (* same number of accounts after adding them to mask *)
            assert (Stdlib.List.compare_lengths parent_list mask_list = 0) ;
            (* should only see the zero balances in mask list *)
            let is_in_same_order =
              List.for_all2_exn parent_list mask_list
                ~f:(fun parent_account mask_account ->
                  Account_id.equal
                    (Account.identifier parent_account)
                    (Account.identifier mask_account) )
            in
            assert is_in_same_order ;
            assert (
              List.for_all mask_list ~f:(fun account ->
                  Balance.equal (Account.balance account) Balance.zero ) ) ) )

  let () =
    add_test "masking in foldi" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts = 10 in
            let account_ids = Account_id.gen_accounts num_accounts in
            (* parent balances all non-zero *)
            let balances =
              List.init num_accounts ~f:(fun n ->
                  Balance.of_nanomina_int_exn (n + 1) )
            in
            let T = Account_id.eq in
            let parent_accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            (* add accounts to parent *)
            List.iter parent_accounts ~f:(fun account ->
                ignore @@ parent_create_new_account_exn maskable account ) ;
            let balance_summer _addr accum acct =
              accum + Balance.to_nanomina_int (Account.balance acct)
            in
            let parent_sum =
              Maskable.foldi maskable ~init:0 ~f:balance_summer
            in
            (* non-zero sum of parent account balances *)
            assert (Int.equal parent_sum 55) (* HT Gauss *) ;
            let zero_balance account =
              Account.update_balance account Balance.zero
            in
            (* put same accounts in mask, but with zero balance *)
            let mask_accounts = List.map parent_accounts ~f:zero_balance in
            List.iter mask_accounts ~f:(fun account ->
                ignore @@ create_existing_account_exn attached_mask account ) ;
            let mask_sum =
              Mask.Attached.foldi attached_mask ~init:0 ~f:balance_summer
            in
            (* sum should not include any parent balances *)
            assert (Int.equal mask_sum 0) ) )

  let () =
    add_test "create_empty doesn't modify the hash" (fun () ->
        Test.with_instances (fun maskable mask ->
            let open Mask.Attached in
            let ledger = Maskable.register_mask maskable mask in
            let key = List.nth_exn (Account_id.gen_accounts 1) 0 in
            let start_hash = merkle_root ledger in
            match
              get_or_create_account ledger key Account.empty |> Or_error.ok_exn
            with
            | `Existed, _ ->
                failwith
                  "create_empty with empty ledger somehow already has that key?"
            | `Added, _new_loc ->
                [%test_eq: Hash.t] start_hash (merkle_root ledger) ) )

  let () =
    add_test "num_accounts for unique keys in mask and parent" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let num_accounts = 5 in
            let account_ids = Account_id.gen_accounts num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let T = Account_id.eq in
            let accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            (* add accounts to mask *)
            List.iter accounts ~f:(fun account ->
                ignore @@ create_new_account_exn attached_mask account ) ;
            let mask_num_accounts_before =
              Mask.Attached.num_accounts attached_mask
            in
            (* add same accounts to parent *)
            List.iter accounts ~f:(fun account ->
                ignore @@ parent_create_new_account_exn maskable account ) ;
            let parent_num_accounts = Maskable.num_accounts maskable in
            (* should not change number of accounts in mask, since they have the same keys *)
            let mask_num_accounts_after =
              Mask.Attached.num_accounts attached_mask
            in
            (* the number of accounts in parent, mask should agree *)
            assert (
              Mina_stdlib.List.Length.Compare.(accounts = parent_num_accounts)
              && Int.equal parent_num_accounts mask_num_accounts_before
              && Int.equal parent_num_accounts mask_num_accounts_after ) ) )

  let () =
    add_test "mask reparenting works" (fun () ->
        Test.with_chain (fun base ~mask:m1_lazy ~mask2:m2_lazy ->
            let num_accounts = 3 in
            let account_ids = Account_id.gen_accounts num_accounts in
            let balances =
              Quickcheck.random_value
                (Quickcheck.Generator.list_with_length num_accounts Balance.gen)
            in
            let T = Account_id.eq in
            let accounts =
              List.map2_exn account_ids balances ~f:Account.create
            in
            match accounts with
            | [ a1; a2; a3 ] ->
                let loc1 = parent_create_new_account_exn base a1 in
                let m1, m1_base = Lazy.force m1_lazy in
                let loc2 = create_new_account_exn m1 a2 in
                let m2 = Lazy.force m2_lazy in
                let loc3 = create_new_account_exn m2 a3 in
                let locs = [ (loc1, a1); (loc2, a2); (loc3, a3) ] in
                (* all accounts are here *)
                List.iter locs ~f:(fun (loc, a) ->
                    [%test_result: Account.t option]
                      ~message:"All accounts are accessible from m2"
                      ~expect:(Some a) (Mask.Attached.get m2 loc) ) ;
                [%test_result: Account.t option] ~message:"a1 is in base"
                  ~expect:(Some a1) (Test.Base.get base loc1) ;
                Mask.Attached.commit m1 ;
                [%test_result: Account.t option] ~message:"a2 is in base"
                  ~expect:(Some a2) (Test.Base.get base loc2) ;
                Maskable.remove_and_reparent_exn m1_base m1 ;
                [%test_result: Account.t option] ~message:"a1 is in base"
                  ~expect:(Some a1) (Test.Base.get base loc1) ;
                [%test_result: Account.t option] ~message:"a2 is in base"
                  ~expect:(Some a2) (Test.Base.get base loc2) ;
                (* all accounts are still here *)
                List.iter locs ~f:(fun (loc, a) ->
                    [%test_result: Account.t option]
                      ~message:"All accounts are accessible from m2"
                      ~expect:(Some a) (Mask.Attached.get m2 loc) )
            | _ ->
                failwith "unexpected" ) )

  let () =
    add_test
      "setting account in parent doesn't remove masked copy if mask is still \
       dirty for said account" (fun () ->
        Test.with_instances (fun maskable mask ->
            let attached_mask = Maskable.register_mask maskable mask in
            let k = Account_id.gen_accounts 1 |> List.hd_exn in
            let T = Account_id.eq in
            let acct1 = Account.create k (Balance.of_nanomina_int_exn 10) in
            let loc =
              Mask.Attached.get_or_create_account attached_mask k acct1
              |> Or_error.ok_exn |> snd
            in
            let acct2 = Account.create k (Balance.of_nanomina_int_exn 5) in
            Maskable.set maskable loc acct2 ;
            [%test_result: Account.t]
              ~message:"account in mask should be unchanged" ~expect:acct1
              (Mask.Attached.get attached_mask loc |> Option.value_exn) ) )

  let tests =
    let actual_tests = Stack.fold test_stack ~init:[] ~f:(fun l e -> e :: l) in
    (test_section_name, actual_tests)
end

module type Depth_S = sig
  val depth : int
end

module Make_maskable_and_mask_with_depth (Depth : Depth_S) = struct
  let depth = Depth.depth

  module Location : Merkle_ledger.Location_intf.S = Merkle_ledger.Location.T

  module Location_binable = struct
    module Arg = struct
      type t = Location.t =
        | Generic of Merkle_ledger.Location.Bigstring.Stable.Latest.t
        | Account of Location.Addr.Stable.Latest.t
        | Hash of Location.Addr.Stable.Latest.t
      [@@deriving bin_io_unversioned, hash, sexp, compare]
    end

    type t = Arg.t =
      | Generic of Merkle_ledger.Location.Bigstring.t
      | Account of Location.Addr.t
      | Hash of Location.Addr.t
    [@@deriving hash, sexp]

    include Comparable.Make_binable (Arg)
    include Hashable.Make_binable (Arg) [@@deriving sexp, compare, hash, yojson]
  end

  module Inputs = struct
    include Test_stubs.Base_inputs
    module Location = Location
    module Location_binable = Location_binable
    module Kvdb = In_memory_kvdb
    module Storage_locations = Storage_locations
  end

  (* underlying Merkle tree *)
  module Base_db :
    Merkle_ledger.Intf.Ledger.DATABASE
      with module Location = Location
       and module Addr = Location.Addr
       and type account := Account.t
       and type root_hash := Hash.t
       and type hash := Hash.t
       and type key := Key.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t =
    Database.Make (Inputs)

  module Any_base = Merkle_ledger.Any_ledger.Make_base (Inputs)
  module Base = Any_base.M

  (* the mask tree *)
  module Mask :
    Merkle_mask.Masking_merkle_tree_intf.S
      with module Location = Location
       and module Attached.Addr = Location.Addr
      with type account := Account.t
       and type location := Location.t
       and type key := Key.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type hash := Hash.t
       and type parent := Base.t = Merkle_mask.Masking_merkle_tree.Make (struct
    include Inputs
    module Base = Base
  end)

  (* tree that can register masks *)
  module Maskable :
    Merkle_mask.Maskable_merkle_tree_intf.S
      with module Addr = Location.Addr
       and module Location = Location
      with type account := Account.t
       and type key := Key.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type root_hash := Hash.t
       and type hash := Hash.t
       and type unattached_mask := Mask.t
       and type attached_mask := Mask.Attached.t
       and type accumulated_t = Mask.accumulated_t
       and type t := Base.t = struct
    type accumulated_t = Mask.accumulated_t

    include Merkle_mask.Maskable_merkle_tree.Make (struct
      include Inputs
      module Base = Base
      module Mask = Mask

      let mask_to_base m = Any_base.cast (module Mask.Attached) m
    end)
  end

  (* test runner *)
  let with_instances f =
    let db = Base_db.create ~depth:Depth.depth () in
    [%test_result: Int.t] ~message:"Base_db num accounts should start at zero"
      ~expect:0 (Base_db.num_accounts db) ;
    let maskable = Any_base.cast (module Base_db) db in
    let mask = Mask.create ~depth:Depth.depth () in
    f maskable mask

  let with_chain f =
    with_instances (fun maskable mask ->
        let attached1 =
          lazy
            (let m = Maskable.register_mask maskable mask in
             (m, Any_base.cast (module Mask.Attached) m) )
        in
        let attached2 =
          lazy
            ( Maskable.register_mask (snd @@ Lazy.force attached1)
            @@ Mask.create ~depth:Depth.depth () )
        in
        f maskable ~mask:attached1 ~mask2:attached2 )
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

let tests = [ Mdb_d4.tests; Mdb_d30.tests ]
