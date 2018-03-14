open Core

let load_ledger n b = 
  let ledger = Test_ledger.create () in
  let keys = List.init n ~f:(fun i -> Int.to_string i) in
  List.iter keys ~f:(fun k -> Test_ledger.update ledger k b);
  (ledger, keys)

let%test "empty_length" = 
  let ledger = Test_ledger.create () in
  Test_ledger.length ledger = 0
;;

let%test "length" = 
  let n = 10 in
  let b = 100 in
  let ledger, keys = load_ledger n b in
  Test_ledger.length ledger = n
;;

let%test "key_retrieval" = 
  let b = 100 in
  let ledger, keys = load_ledger 10 b in
  Some 100 = Test_ledger.get ledger (List.nth_exn keys 0)
;;

let%test "key_nonexist" = 
  let b = 100 in
  let ledger, keys = load_ledger 10 b in
  None = Test_ledger.get ledger "aintioaerntnearst"
;;

let%test_unit "modify_account" = 
  let b = 100 in
  let ledger, keys = load_ledger 10 b in
  let key = List.nth_exn keys 0 in
  assert (Some 100 = Test_ledger.get ledger key);
  Test_ledger.update ledger key 50;
  assert (Some 50 = Test_ledger.get ledger key);
;;

let%test "merkle_root" =
  let ledger = Test_ledger.create () in
  let root = Test_ledger.merkle_root ledger in
  Test_ledger.Hash.hash_unit () = root
;;

let%test "merkle_root_nonempty" =
  let ledger, keys = load_ledger 1 10 in
  let root = Test_ledger.merkle_root ledger in
  Test_ledger.Hash.hash_unit () <> root
;;

let%test_unit "merkle_root_edit" =
  let b1 = 10 in
  let b2 = 50 in
  let n = 10 in
  let ledger, keys = load_ledger n b1 in
  let key = List.nth_exn keys 0 in
  let root0 = Test_ledger.merkle_root ledger in
  assert (Test_ledger.Hash.hash_unit () <> root0);

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

let check_path account (path : Test_ledger.path) root =
  let path_root = 
    List.fold 
      ~init:(Test_ledger.Hash.hash_account account)
      path
      ~f:(fun a b -> 
        match b with
        | Left b -> Test_ledger.Hash.merge a b
        | Right b -> Test_ledger.Hash.merge b a)
  in
  path_root = root

let%test_unit "merkle_path" =
  let b1 = 10 in
  List.iter 
    (List.range 1 20)
    ~f:(fun n -> 
      let ledger, keys = load_ledger n b1 in
      let key = List.nth_exn keys 0 in
      let path = Test_ledger.merkle_path ledger key |> Option.value_exn in
      let account = Test_ledger.get ledger key |> Option.value_exn in
      let root = Test_ledger.merkle_root ledger in
      assert (check_path account path root)
    );
;;

let%test_unit "merkle_path_edits" =
  let b1 = 10 in
  let b2 = 50 in
  let n = 10 in
  let ledger, keys = load_ledger n b1 in
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

