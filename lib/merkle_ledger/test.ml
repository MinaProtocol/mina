open Core

module type S =
  Ledger.S
  with type key := string
   and type hash := Md5.t
   and type account := Test_ledger.Account.t

module type Ledger_intf = sig
  include S

  val load_ledger : int -> int -> t * string list
end

module Ledger (L : S) : Ledger_intf = struct
  include L

  let load_ledger n b =
    let ledger = create () in
    let keys = List.init n ~f:(fun i -> Int.to_string i) in
    List.iter keys ~f:(fun k -> set ledger k {balance= b; key= k}) ;
    (ledger, keys)
end

module L16 = Ledger (Test_ledger.Make (struct
  let depth = 16
end))

module L3 = Ledger (Test_ledger.Make (struct
  let depth = 3
end))

let%test "empty_length" =
  let ledger = L16.create () in
  L16.length ledger = 0

let%test "length" =
  let n = 10 in
  let b = 100 in
  let ledger, _ = L16.load_ledger n b in
  L16.length ledger = n

let gkey = Option.map ~f:(fun {Test_ledger.Account.balance; _} -> balance)

let%test "key_retrieval" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  Some 100 = gkey (L16.get ledger (List.nth_exn keys 0))

let%test "idx_retrieval" =
  let b = 100 in
  let ledger, _keys = L16.load_ledger 10 b in
  match L16.get_at_index ledger 0 with `Ok a -> a.balance = 100 | _ -> false

let%test "key_nonexist" =
  let b = 100 in
  let ledger, _ = L16.load_ledger 10 b in
  None = L16.get ledger "aintioaerntnearst"

let%test "idx_nonexist" =
  let b = 100 in
  let ledger, _keys = L16.load_ledger 10 b in
  `Index_not_found = L16.get_at_index ledger 1234567

let%test_unit "modify_account" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  let key = List.nth_exn keys 0 in
  assert (Some 100 = gkey @@ L16.get ledger key) ;
  L16.set ledger key {balance= 50; key} ;
  assert (Some 50 = gkey @@ L16.get ledger key)

let%test_unit "update_account" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  let key = List.nth_exn keys 0 in
  L16.update ledger key ~f:(function
    | None -> assert false
    | Some {balance; key} -> {balance= balance + 1; key} ) ;
  assert (Some (b + 1) = gkey @@ L16.get ledger key)

let%test_unit "modify_account_by_idx" =
  let b = 100 in
  let ledger, _ = L16.load_ledger 10 b in
  let idx = 0 in
  assert (
    match L16.get_at_index ledger idx with
    | `Ok {balance; _} -> balance = 100
    | _ -> false ) ;
  L16.set_at_index_exn ledger idx {balance= 50; key= Int.to_string idx} ;
  assert (
    match L16.get_at_index ledger idx with
    | `Ok {balance; _} -> balance = 50
    | _ -> false )

let compose_hash n hash =
  let rec go i hash =
    if i = n then hash
    else
      let hash = Test_ledger.Hash.merge ~height:i hash hash in
      go (i + 1) hash
  in
  go 0 hash

let%test "merkle_root" =
  let ledger = L16.create () in
  let root = L16.merkle_root ledger in
  compose_hash 16 Test_ledger.Hash.empty_hash = root

let%test "merkle_root_nonempty" =
  let l = (1 lsl (3 - 1)) + 1 in
  let ledger, _ = L3.load_ledger l 1 in
  let root = L3.merkle_root ledger in
  Test_ledger.Hash.empty_hash <> root

let%test_unit "merkle_root_edit" =
  let b1 = 10 in
  let b2 = 50 in
  let n = 10 in
  let ledger, keys = L16.load_ledger n b1 in
  let key = List.nth_exn keys 0 in
  let root0 = L16.merkle_root ledger in
  assert (Test_ledger.Hash.empty_hash <> root0) ;
  L16.set ledger key {balance= b2; key} ;
  let root1 = L16.merkle_root ledger in
  assert (root1 <> root0) ;
  L16.set ledger key {balance= b1; key} ;
  let root2 = L16.merkle_root ledger in
  assert (root2 = root0) ;
  L16.set ledger key {balance= b2; key} ;
  let root3 = L16.merkle_root ledger in
  assert (root3 = root1)

let check_path account (path: L16.Path.t) root =
  let path_root, _ =
    List.fold path
      ~init:(Test_ledger.Hash.hash_account account, 0)
      ~f:(fun (a, height) b ->
        let a =
          match b with
          | `Left b -> Test_ledger.Hash.merge ~height a b
          | `Right b -> Test_ledger.Hash.merge ~height b a
        in
        (a, height + 1) )
  in
  path_root = root

let little_check_path account (path: L3.Path.t) root =
  let path_root, _ =
    List.fold
      ~init:(Test_ledger.Hash.hash_account account, 0)
      path
      ~f:(fun (a, height) b ->
        let a =
          match b with
          | `Left b -> Test_ledger.Hash.merge ~height a b
          | `Right b -> Test_ledger.Hash.merge ~height b a
        in
        (a, height + 1) )
  in
  path_root = root

let%test_unit "merkle_path" =
  let b1 = 10 in
  List.iter
    (List.range ~stop:`inclusive 1 (1 lsl 3))
    ~f:(fun n ->
      let ledger, keys = L3.load_ledger n b1 in
      let key = List.nth_exn keys 0 in
      let path = L3.merkle_path ledger key |> Option.value_exn in
      let account = L3.get ledger key |> Option.value_exn in
      let root = L3.merkle_root ledger in
      assert (List.length path = 3) ;
      assert (check_path account path root) )

let%test_unit "little_merkle_path" =
  let b1 = 10 in
  List.iter
    (List.range ~stop:`inclusive 1 (1 lsl 3))
    ~f:(fun n ->
      let ledger, keys = L3.load_ledger n b1 in
      let key = List.nth_exn keys 0 in
      let path = L3.merkle_path ledger key |> Option.value_exn in
      let account = L3.get ledger key |> Option.value_exn in
      let root = L3.merkle_root ledger in
      assert (List.length path = 3) ;
      assert (little_check_path account path root) )

let%test_unit "merkle_path_at_index" =
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
      let key = List.nth_exn keys i in
      L16.set ledger key {balance= b2; key} ;
      let path = L16.merkle_path ledger key |> Option.value_exn in
      let account = L16.get ledger key |> Option.value_exn in
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
  L3.set_syncing ledger1 ;
  L3.set_syncing ledger2 ;
  let all_children = all_inner_of (L3.Addr.root ()) in
  List.iter all_children ~f:(fun x ->
      let src = L3.get_inner_hash_at_addr_exn ledger2 x in
      L3.set_inner_hash_at_addr_exn ledger1 x src ) ;
  List.iter (List.range 0 8) ~f:(fun x ->
      let src = L3.get_at_index_exn ledger2 x in
      L3.set_at_index_exn ledger1 x src ) ;
  L3.clear_syncing ledger1 ;
  L3.clear_syncing ledger2 ;
  assert (L3.merkle_root ledger1 = L3.merkle_root ledger2)

let%test_unit "set_inner_hash_at_addr_exn t a h ; get_inner_hash_at_addr_exn \
               t a = h" =
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
  L16.set_syncing ledger ;
  let hash_to_set =
    Test_ledger.Hash.(merge ~height:80 empty_hash empty_hash)
  in
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
        [%test_result : Test_ledger.Hash.hash]
          ~equal:Test_ledger.Hash.equal_hash
          (L16.get_inner_hash_at_addr_exn ledger a)
          ~expect:hash_to_set
      in
      L16.set_inner_hash_at_addr_exn ledger a old_hash ;
      res ) ;
  L16.clear_syncing ledger ;
  assert (mr_start = L16.merkle_root ledger)
