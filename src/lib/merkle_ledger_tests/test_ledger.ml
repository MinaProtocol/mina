open Core
open Unsigned
module Intf = Merkle_ledger.Intf
module Ledger = Merkle_ledger.Ledger

let%test_module "test functor on in memory databases" =
  ( module struct
    module Key = Test_stubs.Key
    module Hash = Test_stubs.Hash
    module Account = Test_stubs.Account

    module Make (Depth : Intf.Depth) = struct
      include Ledger.Make (Key) (Account) (Hash) (Depth)

      type key = Key.t

      type account = Account.t

      type hash = Hash.t

      let load_ledger n b : t * key list =
        let ledger = create () in
        let keys = List.init n ~f:(fun i -> Int.to_string i) in
        List.iter keys ~f:(fun k ->
            let action, _ =
              get_or_create_account_exn ledger k
                {Account.balance= UInt64.of_int b; public_key= k}
            in
            assert (action = `Added) ) ;
        (ledger, keys)
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
      let ledger, _ = L16.load_ledger n b in
      L16.num_accounts ledger = n

    let get (type t key account)
        (module L : Merkle_ledger.Ledger_intf.S
          with type t = t and type key = key and type account = account) ledger
        public_key =
      let open Option.Let_syntax in
      let%bind location = L.location_of_key ledger public_key in
      L.get ledger location

    let gkey = Option.map ~f:(Fn.compose UInt64.to_int Account.balance)

    let%test "key_retrieval" =
      let b = 100 in
      let ledger, keys = L16.load_ledger 10 b in
      Some 100 = gkey (get (module L16) ledger (List.nth_exn keys 0))

    let%test "idx_retrieval" =
      let b = 100 in
      let ledger, _keys = L16.load_ledger 10 b in
      L16.get_at_index_exn ledger 0 |> Account.balance = UInt64.of_int 100

    let%test "key_nonexist" =
      let b = 100 in
      let ledger, _ = L16.load_ledger 10 b in
      None = L16.location_of_key ledger "aintioaerntnearst"

    let%test "idx_nonexist" =
      let b = 100 in
      let ledger, _keys = L16.load_ledger 10 b in
      None = get (module L16) ledger "1234567"

    let%test_unit "modify_account" =
      let initial_balance = 100 in
      let ledger, keys = L16.load_ledger 10 initial_balance in
      let public_key = List.nth_exn keys 0 in
      let location =
        L16.location_of_key ledger public_key |> Option.value_exn
      in
      assert (Some initial_balance = gkey @@ L16.get ledger location) ;
      L16.set ledger location {balance= UInt64.of_int 50; public_key} ;
      assert (Some 50 = gkey @@ L16.get ledger location)

    let%test_unit "modify_account_by_idx" =
      let b = 100 in
      let ledger, _ = L16.load_ledger 10 b in
      let idx = 0 in
      assert (
        L16.get_at_index_exn ledger idx |> Account.balance = UInt64.of_int 100
      ) ;
      let new_b = UInt64.of_int 50 in
      L16.set_at_index_exn ledger idx
        {balance= new_b; public_key= Int.to_string idx} ;
      assert (L16.get_at_index_exn ledger idx |> Account.balance = new_b)

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
      let ledger, _ = L3.load_ledger l 1 in
      let root = L3.merkle_root ledger in
      Hash.empty_account <> root

    let%test_unit "merkle_root_edit" =
      let b1 = 10 in
      let b2 = UInt64.of_int 50 in
      let n = 10 in
      let ledger, keys = L16.load_ledger n b1 in
      let public_key = List.nth_exn keys 0 in
      let root0 = L16.merkle_root ledger in
      let location =
        L16.location_of_key ledger public_key |> Option.value_exn
      in
      assert (Hash.empty_account <> root0) ;
      L16.set ledger location {balance= b2; public_key} ;
      let root1 = L16.merkle_root ledger in
      assert (root1 <> root0) ;
      L16.set ledger location {balance= UInt64.of_int b1; public_key} ;
      let root2 = L16.merkle_root ledger in
      assert (root2 = root0) ;
      L16.set ledger location {balance= b2; public_key} ;
      let root3 = L16.merkle_root ledger in
      assert (root3 = root1)

    module Path = Merkle_ledger.Merkle_path.Make (Hash)

    let check_path account (path : Path.t) root =
      Path.check_path path (Hash.hash_account account) root

    let merkle_path (type t key hash)
        (module L : Merkle_ledger.Ledger_intf.S
          with type t = t and type key = key and type hash = hash) ledger
        public_key =
      L.location_of_key ledger public_key
      |> Option.value_exn |> L.merkle_path ledger

    let%test_unit "merkle_path" =
      let b1 = 10 in
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
      let b1 = 10 in
      let idx = 0 in
      List.iter (List.range 1 20) ~f:(fun n ->
          let ledger, _ = L16.load_ledger n b1 in
          let path = L16.merkle_path_at_index_exn ledger idx in
          let account = L16.get_at_index_exn ledger idx in
          let root = L16.merkle_root ledger in
          assert (List.length path = 16) ;
          assert (check_path account path root) )

    let%test_unit "merkle_path_edits" =
      let b1 = 10 in
      let b2 = 50 in
      let n = 10 in
      let ledger, keys = L16.load_ledger n b1 in
      List.iter (List.range 0 n) ~f:(fun i ->
          let public_key = List.nth_exn keys i in
          let location =
            L16.location_of_key ledger public_key |> Option.value_exn
          in
          L16.set ledger location {balance= UInt64.of_int b2; public_key} ;
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
      let b1 = 1 in
      let b2 = 2 in
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
      let ledger, _ = L16.load_ledger count 1 in
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

    let%test_unit "remove last two accounts is as if they were never there" =
      let l1, _ = L16.load_ledger 8 1 in
      let l2, k2 = L16.load_ledger 10 1 in
      let keys_to_remove = List.drop k2 8 in
      L16.remove_accounts_exn l2 keys_to_remove ;
      assert (L16.merkle_root l1 = L16.merkle_root l2)

    let%test_unit "remove last account is as if it was never there" =
      let l1, _ = L16.load_ledger 9 1 in
      let l2, k2 = L16.load_ledger 10 1 in
      let keys_to_remove = [List.last_exn k2] in
      L16.remove_accounts_exn l2 keys_to_remove ;
      assert (L16.merkle_root l1 = L16.merkle_root l2)

    let%test_unit "removing all accounts is as if there were never accounts" =
      let og_hash = L16.merkle_root (L16.create ()) in
      let l1, keys = L16.load_ledger 10 1 in
      L16.remove_accounts_exn l1 keys ;
      [%test_eq: Hash.t] (L16.merkle_root l1) og_hash

    let%test_unit "set_all_accounts_rooted_at can grow the ledger" =
      let l1, _ = L16.load_ledger 1026 1 in
      let l2, _ = L16.load_ledger 2048 1 in
      let left_subtree =
        L16.get_all_accounts_rooted_at_exn l2
          (L16.Addr.of_directions
             Direction.[Left; Left; Left; Left; Left; Left])
      in
      let right_subtree =
        L16.get_all_accounts_rooted_at_exn l2
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
      Quickcheck.test (Int.gen_incl 2 10) ~trials:10 ~f:(fun depth ->
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
          Quickcheck.test gen ~trials:500
            ~f:(fun (allocated_length, path, subtree_accounts) ->
              let l, _ = L.load_ledger allocated_length 10 in
              L.set_all_accounts_rooted_at_exn l
                (L.Addr.of_directions path)
                subtree_accounts ) )

    let%test_unit "get_inner_hash_at_addr_exn doesn't index layers oob" =
      let l, _ = L16.load_ledger 3001 10 in
      L16.get_inner_hash_at_addr_exn l
        (L16.Addr.of_directions Direction.[Left; Left; Left; Right; Left])
      |> ignore

    let%test_unit "get_inner_hash_at_addr_exn works for any path" =
      Quickcheck.test
        (Int.gen_incl 0 (1 lsl 16))
        ~trials:100 ~shrinker:Int.shrinker
        ~f:(fun len ->
          let l, _ = L16.load_ledger len 10 in
          Quickcheck.test (Direction.gen_var_length_list 16) ~trials:2000
            ~shrinker:(List.shrinker Direction.shrinker) ~f:(fun path ->
              try
                L16.get_inner_hash_at_addr_exn l (L16.Addr.of_directions path)
                |> ignore
              with _ ->
                failwithf
                  !"len: %{sexp:int} with path %{sexp: Direction.t list}"
                  len path () ) )

    let%test_unit "set_all_accounts_rooted_at_exn can work out of order" =
      let l1, _ = L16.load_ledger 8 1 in
      let l2, _ = L16.load_ledger 2 1 in
      let pr = Direction.(List.init 13 ~f:(fun _ -> Left)) in
      let rr = L16.Addr.of_directions Direction.(pr @ [Right; Right]) in
      let rl = L16.Addr.of_directions Direction.(pr @ [Right; Left]) in
      let lr = L16.Addr.of_directions Direction.(pr @ [Left; Right]) in
      let _h = L16.get_inner_hash_at_addr_exn l2 lr in
      let copy addr =
        L16.set_all_accounts_rooted_at_exn l2 addr
          (L16.get_all_accounts_rooted_at_exn l1 addr)
      in
      copy rr ;
      copy rl ;
      copy lr ;
      assert (L16.num_accounts l2 = 8)
  end )
