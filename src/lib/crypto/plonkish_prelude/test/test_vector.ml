let test_initialize_with_correct_size () =
  let v =
    Plonkish_prelude.Vector.init Plonkish_prelude.Nat.N10.n ~f:(fun i -> i)
  in
  assert (Plonkish_prelude.(Nat.to_int (Vector.length v)) = 10)

let test_split () =
  (* v is of length 10. We want to split in two vectors of size 6 and 4 *)
  let v =
    Plonkish_prelude.Vector.init Plonkish_prelude.Nat.N10.n ~f:(fun i -> i)
  in
  (* 6 + 4 *)
  let ten = snd (Plonkish_prelude.Nat.N6.add Plonkish_prelude.Nat.N4.n) in
  let v_6, v_4 = Plonkish_prelude.Vector.split v ten in
  (* Checking the size of both splits *)
  assert (Plonkish_prelude.(Nat.to_int (Vector.length v_6)) = 6) ;
  assert (Plonkish_prelude.(Nat.to_int (Vector.length v_4)) = 4) ;
  (* We will now check the elements have been splitted correctly, we should have
     0 to 5 in v_6 and 6 to 9 in v_4 *)
  let v_6_list = Plonkish_prelude.Vector.to_list v_6 in
  assert (List.for_all2_exn v_6_list (List.init 6 ~f:(fun i -> i)) ~f:Int.equal) ;
  let v_4_list = Plonkish_prelude.Vector.to_list v_4 in
  assert (
    List.for_all2_exn v_4_list (List.init 4 ~f:(fun i -> 6 + i)) ~f:Int.equal )

(* [Vector_n.Stable.V1] encodes the elements in order followed by the unit
   byte, the layout the [Cata] nested-pair combinators produced before the
   sizer, writer and reader were hand-rolled. These pin the literal bytes:
   a self-consistent change to writer and reader still round-trips, but
   would split from nodes running the old code, since [Vector_2] through
   [Vector_32] are in the proof encoding. *)
let test_bin_prot_layout () =
  let module V4 = Plonkish_prelude.Vector.Vector_4 in
  let v = V4.of_list_exn [ 1; 2; 3; 4 ] in
  let expected = "\001\002\003\004\000" in
  Alcotest.(check int)
    "bin_size_t" (String.length expected)
    (V4.Stable.V1.bin_size_t Int.bin_size_t v) ;
  let buf = Bigstring.create 32 in
  let len = V4.Stable.V1.bin_write_t Int.bin_write_t buf ~pos:0 v in
  Alcotest.(check string)
    "bin_write_t bytes" expected
    (Bigstring.To_string.sub buf ~pos:0 ~len) ;
  let pos_ref = ref 0 in
  let v' = V4.Stable.V1.bin_read_t Int.bin_read_t buf ~pos_ref in
  Alcotest.(check (list int))
    "bin_read_t inverts" [ 1; 2; 3; 4 ] (V4.to_list v') ;
  Alcotest.(check int) "bin_read_t consumes the unit byte" len !pos_ref

(* Nested vectors keep the inner unit byte after each inner vector, then the
   outer one. *)
let test_bin_prot_layout_nested () =
  let module V2 = Plonkish_prelude.Vector.Vector_2 in
  let module V4 = Plonkish_prelude.Vector.Vector_4 in
  let vv =
    V2.of_list_exn
      [ V4.of_list_exn [ 1; 2; 3; 4 ]; V4.of_list_exn [ 5; 6; 7; 8 ] ]
  in
  let expected = "\001\002\003\004\000\005\006\007\008\000\000" in
  let inner_write = V4.Stable.V1.bin_write_t Int.bin_write_t in
  let inner_read = V4.Stable.V1.bin_read_t Int.bin_read_t in
  Alcotest.(check int)
    "bin_size_t" (String.length expected)
    (V2.Stable.V1.bin_size_t (V4.Stable.V1.bin_size_t Int.bin_size_t) vv) ;
  let buf = Bigstring.create 32 in
  let len = V2.Stable.V1.bin_write_t inner_write buf ~pos:0 vv in
  Alcotest.(check string)
    "bin_write_t bytes" expected
    (Bigstring.To_string.sub buf ~pos:0 ~len) ;
  let pos_ref = ref 0 in
  let vv' = V2.Stable.V1.bin_read_t inner_read buf ~pos_ref in
  Alcotest.(check (list (list int)))
    "bin_read_t inverts"
    [ [ 1; 2; 3; 4 ]; [ 5; 6; 7; 8 ] ]
    (List.map (V2.to_list vv') ~f:V4.to_list) ;
  Alcotest.(check int) "bin_read_t consumes both unit bytes" len !pos_ref

let tests =
  let open Alcotest in
  [ ( "Vectors"
    , [ test_case "test initialize with correct size" `Quick
          test_initialize_with_correct_size
      ; test_case "test split" `Quick test_split
      ; test_case "bin_prot layout" `Quick test_bin_prot_layout
      ; test_case "bin_prot layout, nested" `Quick test_bin_prot_layout_nested
      ] )
  ]
