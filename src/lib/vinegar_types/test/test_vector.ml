let test_initialize_with_correct_size () =
  let v = Pickles_types.Vector.init Pickles_types.Nat.N10.n ~f:(fun i -> i) in
  assert (Pickles_types.(Nat.to_int (Vector.length v)) = 10)

let test_split () =
  (* v is of length 10. We want to split in two vectors of size 6 and 4 *)
  let v = Pickles_types.Vector.init Pickles_types.Nat.N10.n ~f:(fun i -> i) in
  (* 6 + 4 *)
  let ten = snd (Pickles_types.Nat.N6.add Pickles_types.Nat.N4.n) in
  let v_6, v_4 = Pickles_types.Vector.split v ten in
  (* Checking the size of both splits *)
  assert (Pickles_types.(Nat.to_int (Vector.length v_6)) = 6) ;
  assert (Pickles_types.(Nat.to_int (Vector.length v_4)) = 4) ;
  (* We will now check the elements have been splitted correctly, we should have
     0 to 5 in v_6 and 6 to 9 in v_4 *)
  let v_6_list = Pickles_types.Vector.to_list v_6 in
  assert (List.for_all2_exn v_6_list (List.init 6 ~f:(fun i -> i)) ~f:Int.equal) ;
  let v_4_list = Pickles_types.Vector.to_list v_4 in
  assert (
    List.for_all2_exn v_4_list (List.init 4 ~f:(fun i -> 6 + i)) ~f:Int.equal )

let tests =
  let open Alcotest in
  [ ( "Vectors"
    , [ test_case "test initialize with correct size" `Quick
          test_initialize_with_correct_size
      ; test_case "test split" `Quick test_split
      ] )
  ]
