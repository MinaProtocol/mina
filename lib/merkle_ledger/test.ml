open Core

let load_ledger d n b = 
  let ledger = Test_ledger.create d in
  let keys = List.init n ~f:(fun i -> Int.to_string i) in
  List.iter keys ~f:(fun k -> Test_ledger.update ledger k b);
  (ledger, keys)

let%test "empty_length" = 
  let ledger = Test_ledger.create 16 in
  Test_ledger.length ledger = 0
;;

let%test "length" = 
  let n = 10 in
  let b = 100 in
  let d = 16 in
  let ledger, keys = load_ledger d n b in
  Test_ledger.length ledger = n
;;

let%test "key_retrieval" = 
  let b = 100 in
  let d = 16 in
  let ledger, keys = load_ledger d 10 b in
  Some 100 = Test_ledger.get ledger (List.nth_exn keys 0)
;;

let%test "idx_retrieval" = 
  let b = 100 in
  let d = 16 in
  let ledger, _keys = load_ledger d 10 b in
  `Ok 100 = Test_ledger.get_at_index ledger 0
;;

let%test "key_nonexist" = 
  let b = 100 in
  let d = 16 in
  let ledger, keys = load_ledger d 10 b in
  None = Test_ledger.get ledger "aintioaerntnearst"
;;

let%test "idx_nonexist" = 
  let b = 100 in
  let d = 16 in
  let ledger, _keys = load_ledger d 10 b in
  `Index_not_found = Test_ledger.get_at_index ledger 1234567
;;

let%test_unit "modify_account" = 
  let b = 100 in
  let d = 16 in
  let ledger, keys = load_ledger d 10 b in
  let key = List.nth_exn keys 0 in
  assert (Some 100 = Test_ledger.get ledger key);
  Test_ledger.update ledger key 50;
  assert (Some 50 = Test_ledger.get ledger key);
;;

let%test_unit "modify_account_by_idx" = 
  let b = 100 in
  let d = 16 in
  let ledger, keys = load_ledger d 10 b in
  let idx = 0 in
  assert (`Ok 100 = Test_ledger.get_at_index ledger idx);
  Test_ledger.update_at_index_exn ledger idx 50;
  assert (`Ok 50 = Test_ledger.get_at_index ledger idx);
;;

let rec compose_hash i hash =
  let hash = Test_ledger.Hash.merge hash hash in
  if i = 0
  then hash
  else compose_hash (i-1) hash

let%test "merkle_root" =
  let d = 16 in
  let ledger = Test_ledger.create d in
  let root = Test_ledger.merkle_root ledger in
  (compose_hash (d - 1) Test_ledger.Hash.empty_hash) = root
;;

let%test "merkle_root_nonempty" =
  let d = 3 in
  let ledger, keys = load_ledger d (1 lsl d) 1 in
  let root = Test_ledger.merkle_root ledger in
  Test_ledger.Hash.empty_hash <> root
;;

let%test_unit "merkle_root_edit" =
  let b1 = 10 in
  let b2 = 50 in
  let n = 10 in
  let d = 16 in
  let ledger, keys = load_ledger d n b1 in
  let key = List.nth_exn keys 0 in
  let root0 = Test_ledger.merkle_root ledger in
  assert (Test_ledger.Hash.empty_hash <> root0);

  Test_ledger.update ledger key b2;
  let root1 = Test_ledger.merkle_root ledger in
  assert (root1 <> root0);

  Test_ledger.update ledger key b1;
  let root2 = Test_ledger.merkle_root ledger in
  assert (root2 = root0);

  Test_ledger.update ledger key b2;
  let root3 = Test_ledger.merkle_root ledger in
  assert (root3 = root1);
;;

let check_path account (path : Test_ledger.Path.t) root =
  let path_root = 
    List.fold 
      ~init:(Test_ledger.Hash.hash_account account)
      path
      ~f:(fun a b -> 
        match b with
        | `Left b -> Test_ledger.Hash.merge a b
        | `Right b -> Test_ledger.Hash.merge b a)
  in
  path_root = root

let%test_unit "merkle_path" =
  let b1 = 10 in
  let d = 3 in
  List.iter (List.range ~stop:`inclusive 1 (1 lsl d))
    ~f:(fun n -> 
      let ledger, keys = load_ledger d n b1 in
      let key = List.nth_exn keys 0 in
      let path = Test_ledger.merkle_path ledger key |> Option.value_exn in
      let account = Test_ledger.get ledger key |> Option.value_exn in
      let root = Test_ledger.merkle_root ledger in
      assert (List.length path = d);
      assert (check_path account path root)
    );
;;

let%test_unit "merkle_path_at_index" =
  let b1 = 10 in
  let d = 16 in
  let idx = 0 in
  List.iter (List.range 1 20)
    ~f:(fun n -> 
      let ledger, keys = load_ledger d n b1 in
      let path = Test_ledger.merkle_path_at_index_exn ledger idx in
      let account = Test_ledger.get_at_index_exn ledger idx in
      let root = Test_ledger.merkle_root ledger in
      assert (List.length path = d);
      assert (check_path account path root)
    );
;;

let%test_unit "merkle_path_edits" =
  let b1 = 10 in
  let b2 = 50 in
  let n = 10 in
  let d = 16 in 
  let ledger, keys = load_ledger d n b1 in
  List.iter (List.range 0 n)
    ~f:(fun i -> 
      let key = List.nth_exn keys i in
      Test_ledger.update ledger key b2;
      let path = Test_ledger.merkle_path ledger key |> Option.value_exn in
      let account = Test_ledger.get ledger key |> Option.value_exn in
      let root = Test_ledger.merkle_root ledger in
      assert (check_path account path root)
    );
;;
