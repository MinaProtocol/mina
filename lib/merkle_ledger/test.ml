open Core

module type S =
  Ledger.S
  with type key := string
   and type hash := Md5.t
   and type account := int

module Ledger (L : S) = struct
  include L

  let load_ledger n b =
    let ledger = create () in
    let keys = List.init n ~f:(fun i -> Int.to_string i) in
    List.iter keys ~f:(fun k -> set ledger k b) ;
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
  let ledger, keys = L16.load_ledger n b in
  L16.length ledger = n

let%test "key_retrieval" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  Some 100 = L16.get ledger (List.nth_exn keys 0)

let%test "idx_retrieval" =
  let b = 100 in
  let ledger, _keys = L16.load_ledger 10 b in
  `Ok 100 = L16.get_at_index ledger 0

let%test "key_nonexist" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  None = L16.get ledger "aintioaerntnearst"

let%test "idx_nonexist" =
  let b = 100 in
  let ledger, _keys = L16.load_ledger 10 b in
  `Index_not_found = L16.get_at_index ledger 1234567

let%test_unit "modify_account" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  let key = List.nth_exn keys 0 in
  assert (Some 100 = L16.get ledger key) ;
  L16.set ledger key 50 ;
  assert (Some 50 = L16.get ledger key)

let%test_unit "update_account" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  let key = List.nth_exn keys 0 in
  L16.update ledger key ~f:(function None -> assert false | Some x -> x + 1) ;
  assert (Some (b + 1) = L16.get ledger key)

let%test_unit "modify_account_by_idx" =
  let b = 100 in
  let ledger, keys = L16.load_ledger 10 b in
  let idx = 0 in
  assert (`Ok 100 = L16.get_at_index ledger idx) ;
  L16.set_at_index_exn ledger idx 50 ;
  assert (`Ok 50 = L16.get_at_index ledger idx)

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
  let ledger, keys = L3.load_ledger l 1 in
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
  L16.set ledger key b2 ;
  let root1 = L16.merkle_root ledger in
  assert (root1 <> root0) ;
  L16.set ledger key b1 ;
  let root2 = L16.merkle_root ledger in
  assert (root2 = root0) ;
  L16.set ledger key b2 ;
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
      let ledger, keys = L16.load_ledger n b1 in
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
      L16.set ledger key b2 ;
      let path = L16.merkle_path ledger key |> Option.value_exn in
      let account = L16.get ledger key |> Option.value_exn in
      let root = L16.merkle_root ledger in
      assert (check_path account path root) )

let%test_unit "set_inner_can_copy_correctly" =
  let rec all_inner_of a =
    if L3.Addr.depth a = L3.depth - 1 then []
    else
      let lc = L3.Addr.child a `Left in
      let rc = L3.Addr.child a `Right in
      match (lc, rc) with
      | Ok lc, Ok rc -> [lc; rc] @ all_inner_of lc @ all_inner_of rc
      | _ -> []
  in
  let n = 8 in
  let b1 = 1 in
  let b2 = 2 in
  let ledger1, keys1 = L3.load_ledger n b1 in
  let ledger2, keys2 = L3.load_ledger n b2 in
  L3.set_syncing ledger1 ;
  L3.set_syncing ledger2 ;
  let all_children = all_inner_of L3.Addr.root in
  List.iter all_children ~f:(fun x ->
      let src = L3.get_inner_hash_at_addr_exn ledger2 x in
      L3.set_inner_hash_at_addr_exn ledger1 x src ) ;
  List.iter (List.range 0 8) ~f:(fun x ->
      let src = L3.get_at_index_exn ledger2 x in
      L3.set_at_index_exn ledger1 x src ) ;
  L3.clear_syncing ledger1 ;
  L3.clear_syncing ledger2 ;
  assert (L3.merkle_root ledger1 = L3.merkle_root ledger2)
