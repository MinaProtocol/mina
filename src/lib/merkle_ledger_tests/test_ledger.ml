open Core
module Intf = Merkle_ledger.Intf
module Ledger = Merkle_ledger.Ledger

let%test_module "test functor on in memory databases" =
  ( module struct
    module Key_with_gen = Test_stubs.Key
    module Hash = Test_stubs.Hash
    module Account = Test_stubs.Account
    module Receipt = Test_stubs.Receipt
    module Balance = Test_stubs.Balance

    module Make (Depth : Intf.Depth) = struct
      include Ledger.Make (struct
        include Test_stubs.Base_inputs
        module Depth = Depth
      end)

      type key = Key_with_gen.t

      type key_set = Key_with_gen.Set.t

      type account = Account.t

      type hash = Hash.t

      type root_hash = Hash.t

      let load_ledger_with_keys keys balance =
        let ledger = create () in
        List.iter keys ~f:(fun public_key ->
            let action, _ =
              get_or_create_account_exn ledger public_key
                (Account.create public_key balance)
            in
            assert (action = `Added) ) ;
        (ledger, keys)

      let load_ledger num_accounts balance : t * key list =
        let keys = Key_with_gen.gen_keys num_accounts in
        load_ledger_with_keys keys balance
    end

    module L16 = Make (struct
      let depth = 16
    end)

    module L3 = Make (struct
      let depth = 3
    end)

    let%test "empty_length" =
      let ledger = L16.create () in
      L16.num_accounts ledger = 0

    let%test "length" =
      let n = 10 in
      let b = 100 in
      let ledger, _ = L16.load_ledger n (Balance.of_int b) in
      L16.num_accounts ledger = n

    let get (type t key account)
        (module L : Merkle_ledger.Ledger_extras_intf.S
          with type t = t and type key = key and type account = account) ledger
        public_key =
      let open Option.Let_syntax in
      let%bind location = L.location_of_key ledger public_key in
      L.get ledger location

    let gkey = Option.map ~f:(Fn.compose Balance.to_int Account.balance)

    let%test "key_retrieval" =
      let b = 100 in
      let ledger, keys = L16.load_ledger 10 (Balance.of_int b) in
      Some 100 = gkey (get (module L16) ledger (List.nth_exn keys 0))

    let%test "idx_retrieval" =
      let b = 100 in
      let ledger, _keys = L16.load_ledger 10 (Balance.of_int b) in
      L16.get_at_index_exn ledger 0 |> Account.balance = Balance.of_int 100

    let%test "key_nonexist" =
      let b = 100 in
      let ledger, _ = L16.load_ledger 10 (Balance.of_int b) in
      let key =
        Quickcheck.random_value ~seed:(`Deterministic "key_nonexist")
          Key_with_gen.gen
      in
      None = L16.location_of_key ledger key

    let%test "idx_nonexist" =
      let b = 100 in
      let ledger, _keys = L16.load_ledger 10 (Balance.of_int b) in
      let key =
        Quickcheck.random_value ~seed:(`Deterministic "idx_nonexist")
          Key_with_gen.gen
      in
      None = get (module L16) ledger key

    let%test_unit "modify_account" =
      let initial_balance = 100 in
      let ledger, keys = L16.load_ledger 10 (Balance.of_int initial_balance) in
      let public_key = List.nth_exn keys 0 in
      let location =
        L16.location_of_key ledger public_key |> Option.value_exn
      in
      assert (Some initial_balance = gkey @@ L16.get ledger location) ;
      let account = Account.create public_key (Balance.of_int 50) in
      L16.set ledger location account ;
      assert (Some 50 = gkey @@ L16.get ledger location)

    let%test_unit "modify_account_by_idx" =
      let b = 100 in
      let ledger, _ = L16.load_ledger 10 (Balance.of_int b) in
      let idx = 0 in
      assert (
        L16.get_at_index_exn ledger idx |> Account.balance = Balance.of_int 100
      ) ;
      let new_b = Balance.of_int 50 in
      let public_key =
        Quickcheck.random_value ~seed:(`Deterministic "modify_account_by_idx")
          Key_with_gen.gen
      in
      L16.set_at_index_exn ledger idx (Account.create public_key new_b) ;
      assert (
        L16.get_at_index_exn ledger idx
        |> fun account -> Balance.equal (Account.balance account) new_b )

    let compose_hash n hash =
      let rec go i hash =
        if i = n then hash
        else
          let hash = Hash.merge ~height:i hash hash in
          go (i + 1) hash
      in
      go 0 hash

    let%test "merkle_root" =
      let ledger = L16.create () in
      let root = L16.merkle_root ledger in
      compose_hash 16 Hash.empty_account = root

    let%test "merkle_root_nonempty" =
      let l = (1 lsl (3 - 1)) + 1 in
      let ledger, _ = L3.load_ledger l Balance.one in
      let root = L3.merkle_root ledger in
      Hash.empty_account <> root

    let%test_unit "merkle_root_edit" =
      let b1 = Balance.of_int 10 in
      let b2 = Balance.of_int 50 in
      let n = 10 in
      let ledger, keys = L16.load_ledger n b1 in
      let public_key = List.nth_exn keys 0 in
      let root0 = L16.merkle_root ledger in
      let location =
        L16.location_of_key ledger public_key |> Option.value_exn
      in
      assert (Hash.empty_account <> root0) ;
      L16.set ledger location (Account.create public_key b2) ;
      let root1 = L16.merkle_root ledger in
      assert (root1 <> root0) ;
      L16.set ledger location (Account.create public_key b1) ;
      let root2 = L16.merkle_root ledger in
      assert (root2 = root0) ;
      L16.set ledger location (Account.create public_key b2) ;
      let root3 = L16.merkle_root ledger in
      assert (root3 = root1)

    module Path = Merkle_ledger.Merkle_path.Make (Hash)

    let check_path account (path : Path.t) root =
      Path.check_path path (Hash.hash_account account) root

    let merkle_path (type t key hash)
        (module L : Merkle_ledger.Ledger_extras_intf.S
          with type t = t and type key = key and type hash = hash) ledger
        public_key =
      L.location_of_key ledger public_key
      |> Option.value_exn |> L.merkle_path ledger

    let%test_unit "merkle_path" =
      let b1 = Balance.of_int 10 in
      List.iter
        (List.range ~stop:`inclusive 1 (1 lsl 3))
        ~f:(fun n ->
          let ledger, keys = L3.load_ledger n b1 in
          let key = List.nth_exn keys 0 in
          let path = merkle_path (module L3) ledger key in
          let account = get (module L3) ledger key |> Option.value_exn in
          let root = L3.merkle_root ledger in
          assert (List.length path = 3) ;
          assert (check_path account path root) )

    let%test_unit "merkle_path_at_index_exn" =
      let b1 = Balance.of_int 10 in
      let idx = 0 in
      List.iter (List.range 1 20) ~f:(fun n ->
          let ledger, _ = L16.load_ledger n b1 in
          let path = L16.merkle_path_at_index_exn ledger idx in
          let account = L16.get_at_index_exn ledger idx in
          let root = L16.merkle_root ledger in
          assert (List.length path = 16) ;
          assert (check_path account path root) )

    let%test_unit "merkle_path_edits" =
      let b1 = Balance.of_int 10 in
      let b2 = Balance.of_int 50 in
      let n = 10 in
      let ledger, keys = L16.load_ledger n b1 in
      List.iter (List.range 0 n) ~f:(fun i ->
          let public_key = List.nth_exn keys i in
          let location =
            L16.location_of_key ledger public_key |> Option.value_exn
          in
          L16.set ledger location (Account.create public_key b2) ;
          let path = merkle_path (module L16) ledger public_key in
          let account = L16.get ledger location |> Option.value_exn in
          let root = L16.merkle_root ledger in
          assert (check_path account path root) )

    let%test_unit "set_inner_can_copy_correctly" =
      let rec all_inner_of a =
        if L3.Addr.depth a = L3.depth - 1 then []
        else
          let lc = L3.Addr.child a Left in
          let rc = L3.Addr.child a Right in
          match (lc, rc) with
          | Ok lc, Ok rc -> [lc; rc] @ all_inner_of lc @ all_inner_of rc
          | _ -> []
      in
      let n = 8 in
      let b1 = Balance.of_int 1 in
      let b2 = Balance.of_int 2 in
      let ledger1, _ = L3.load_ledger n b1 in
      let ledger2, _ = L3.load_ledger n b2 in
      L3.recompute_tree ledger1 ;
      L3.recompute_tree ledger2 ;
      let all_children = all_inner_of (L3.Addr.root ()) in
      List.iter all_children ~f:(fun x ->
          let src = L3.get_inner_hash_at_addr_exn ledger2 x in
          L3.set_inner_hash_at_addr_exn ledger1 x src ) ;
      List.iter (List.range 0 8) ~f:(fun x ->
          let src = L3.get_at_index_exn ledger2 x in
          L3.set_at_index_exn ledger1 x src ) ;
      assert (L3.merkle_root ledger1 = L3.merkle_root ledger2)

    let%test_unit "set_inner_hash_at_addr_exn t a h ; \
                   get_inner_hash_at_addr_exn t a = h" =
      let rec repeated n f r = if n > 0 then repeated (n - 1) f (f r) else r in
      let rec mk_addr ix h a =
        if h = 0 then a
        else if ix land 1 = 1 then
          mk_addr (ix lsr 1) (h - 1) (L16.Addr.child_exn a Right)
        else mk_addr (ix lsr 1) (h - 1) (L16.Addr.child_exn a Left)
      in
      let count = 8192 in
      let ledger, _ = L16.load_ledger count (Balance.of_int 1) in
      let mr_start = L16.merkle_root ledger in
      let max_height = Int.ceil_log2 count in
      let hash_to_set = Hash.(merge ~height:80 empty_account empty_account) in
      let open Quickcheck.Generator in
      Quickcheck.test
        (tuple2 (Int.gen_incl 0 8192) (Int.gen_incl 0 (max_height - 1)))
        ~f:(fun (idx, height) ->
          let a =
            mk_addr idx height
              (repeated (L16.depth - max_height)
                 (fun a -> L16.Addr.child_exn a Left)
                 (L16.Addr.root ()))
          in
          let old_hash = L16.get_inner_hash_at_addr_exn ledger a in
          L16.set_inner_hash_at_addr_exn ledger a hash_to_set ;
          let res =
            [%test_result: Hash.t] ~equal:Hash.equal
              (L16.get_inner_hash_at_addr_exn ledger a)
              ~expect:hash_to_set
          in
          L16.set_inner_hash_at_addr_exn ledger a old_hash ;
          res ) ;
      assert (mr_start = L16.merkle_root ledger)

    let%test_unit "create_empty doesn't modify the hash" =
      let open L3 in
      let key = List.nth_exn (Key_with_gen.gen_keys 1) 0 in
      let ledger = create () in
      let start_hash = merkle_root ledger in
      match get_or_create_account_exn ledger key Account.empty with
      | `Existed, _ ->
          failwith
            "create_empty with empty ledger somehow already has that key?"
      | `Added, _new_loc -> [%test_eq: Hash.t] start_hash (merkle_root ledger)

    let%test_unit "remove last two accounts is as if they were never there" =
      (* NB: because of the issue with duplicates in public _key generation,
         given numbers of accounts n and m, where m > n, the key list produced by load_ledger on n
         is not necessarily a prefix of the list for load_ledger on m

         therefore, we produce the key list separately, take a prefix, and pass that to load_ledger_with_keys
       *)
      let all_keys = Key_with_gen.gen_keys 10 in
      let l1_keys = List.take all_keys 8 in
      let l1, _ = L16.load_ledger_with_keys l1_keys Balance.one in
      let l2_keys = all_keys in
      let l2, k2 = L16.load_ledger_with_keys l2_keys Balance.one in
      let keys_to_remove = List.drop k2 8 in
      L16.remove_accounts_exn l2 keys_to_remove ;
      assert (L16.merkle_root l1 = L16.merkle_root l2)

    let%test_unit "remove last account is as if it were never there" =
      (* see remark in previous test about load_ledger *)
      let all_keys = Key_with_gen.gen_keys 10 in
      let l1_keys = List.take all_keys 9 in
      let l1, _ = L16.load_ledger_with_keys l1_keys Balance.one in
      let l2_keys = all_keys in
      let l2, k2 = L16.load_ledger_with_keys l2_keys Balance.one in
      let keys_to_remove = [List.last_exn k2] in
      L16.remove_accounts_exn l2 keys_to_remove ;
      assert (L16.merkle_root l1 = L16.merkle_root l2)

    let%test_unit "removing all accounts is as if there were never accounts" =
      let og_hash = L16.merkle_root (L16.create ()) in
      let l1, keys = L16.load_ledger 10 Balance.one in
      L16.remove_accounts_exn l1 keys ;
      [%test_eq: Hash.t] (L16.merkle_root l1) og_hash

    let%test_unit "set_all_accounts_rooted_at can grow the ledger" =
      let l1, _ = L16.load_ledger 1026 Balance.one in
      let l2, _ = L16.load_ledger 2048 Balance.one in
      let left_subtree =
        List.map ~f:snd
        @@ L16.get_all_accounts_rooted_at_exn l2
             (L16.Addr.of_directions
                Direction.[Left; Left; Left; Left; Left; Left])
      in
      let right_subtree =
        List.map ~f:snd
        @@ L16.get_all_accounts_rooted_at_exn l2
             (L16.Addr.of_directions
                Direction.[Left; Left; Left; Left; Left; Right])
      in
      L16.set_all_accounts_rooted_at_exn l1
        (L16.Addr.of_directions Direction.[Left; Left; Left; Left; Left; Left])
        left_subtree ;
      L16.set_all_accounts_rooted_at_exn l1
        (L16.Addr.of_directions Direction.[Left; Left; Left; Left; Left; Right])
        right_subtree ;
      [%test_eq: Hash.t] (L16.merkle_root l1) (L16.merkle_root l2)

    let%test_unit "set_all_accounts_rooted_at . get_all_accounts_rooted_at \
                   works for any root" =
      Quickcheck.test (Int.gen_incl 2 10) ~trials:8 ~f:(fun depth ->
          let module L = Make (struct
            let depth = depth
          end) in
          let gen =
            let open Quickcheck.Generator.Let_syntax in
            let%bind subtree_depth = Int.gen_incl 0 depth in
            let%bind path = Direction.gen_list subtree_depth in
            let subtree_length = 1 lsl (depth - subtree_depth) in
            let%bind subtree_accounts =
              List.gen_with_length subtree_length Account.gen
            in
            let%bind allocated_length = Int.gen_incl 0 (1 lsl depth) in
            return (allocated_length, path, subtree_accounts)
          in
          Quickcheck.test gen ~trials:50
            ~f:(fun (allocated_length, path, subtree_accounts) ->
              let l, _ = L.load_ledger allocated_length (Balance.of_int 10) in
              L.set_all_accounts_rooted_at_exn l
                (L.Addr.of_directions path)
                subtree_accounts ) )

    let%test_unit "get_inner_hash_at_addr_exn doesn't index layers oob" =
      let l, _ = L16.load_ledger 3001 (Balance.of_int 10) in
      L16.get_inner_hash_at_addr_exn l
        (L16.Addr.of_directions Direction.[Left; Left; Left; Right; Left])
      |> ignore

    let%test_unit "get_inner_hash_at_addr_exn works for any path" =
      Quickcheck.test
        (Int.gen_incl 0 (1 lsl 16))
        ~trials:8 ~shrinker:Int.shrinker
        ~f:(fun len ->
          let l, _ = L16.load_ledger len (Balance.of_int 10) in
          Quickcheck.test (Direction.gen_var_length_list 16) ~trials:10
            ~shrinker:(List.shrinker Direction.shrinker) ~f:(fun path ->
              try
                L16.get_inner_hash_at_addr_exn l (L16.Addr.of_directions path)
                |> ignore
              with _ ->
                failwithf
                  !"len: %{sexp:int} with path %{sexp: Direction.t list}"
                  len path () ) )

    let%test_unit "set_all_accounts_rooted_at_exn can work out of order" =
      (* see remark for test "remove last two accounts is as if they were never there" above *)
      let all_keys = Key_with_gen.gen_keys 8 in
      let l1_keys = all_keys in
      let l1, _ = L16.load_ledger_with_keys l1_keys Balance.one in
      let l2_keys = List.take all_keys 2 in
      let l2, _ = L16.load_ledger_with_keys l2_keys Balance.one in
      let pr = Direction.(List.init 13 ~f:(fun _ -> Left)) in
      let rr = L16.Addr.of_directions Direction.(pr @ [Right; Right]) in
      let rl = L16.Addr.of_directions Direction.(pr @ [Right; Left]) in
      let lr = L16.Addr.of_directions Direction.(pr @ [Left; Right]) in
      let _h = L16.get_inner_hash_at_addr_exn l2 lr in
      let copy addr =
        L16.set_all_accounts_rooted_at_exn l2 addr
          (List.map ~f:snd @@ L16.get_all_accounts_rooted_at_exn l1 addr)
      in
      copy rr ;
      copy rl ;
      copy lr ;
      assert (L16.num_accounts l2 = 8)
  end )
