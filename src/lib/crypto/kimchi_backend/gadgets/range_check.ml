open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* Helper to create RangeCheck0 gate, configured in various ways
 *     - is_64bit   : create 64-bit range check
 *     - is_compact : compact limbs mode (only used by compact multi-range-check)
 *)
let range_check0 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(is_64bit : bool = false) ?(is_compact : bool = false)
    (v0 : Circuit.Field.t) =
  let open Circuit in
  (* Define a shorthand helper *)
  let bits_le_to_field = Common.field_bits_le_to_field (module Circuit) in

  (* Create sublimbs
   *   Note: when v0p0 and v0p1 are zero snary will automatically supply the copy constraints
   *)
  let v0p0 = if is_64bit then Field.zero else bits_le_to_field v0 76 88 in
  let v0p1 = if is_64bit then Field.zero else bits_le_to_field v0 64 76 in
  let v0p2 = bits_le_to_field v0 52 64 in
  let v0p3 = bits_le_to_field v0 40 52 in
  let v0p4 = bits_le_to_field v0 28 40 in
  let v0p5 = bits_le_to_field v0 16 28 in
  let v0c0 = bits_le_to_field v0 14 16 in
  let v0c1 = bits_le_to_field v0 12 14 in
  let v0c2 = bits_le_to_field v0 10 12 in
  let v0c3 = bits_le_to_field v0 8 10 in
  let v0c4 = bits_le_to_field v0 6 8 in
  let v0c5 = bits_le_to_field v0 4 6 in
  let v0c6 = bits_le_to_field v0 2 4 in
  let v0c7 = bits_le_to_field v0 0 2 in

  (* Set up compact mode coefficient *)
  let compact =
    if is_compact then Field.Constant.one else Field.Constant.zero
  in

  (* Prepare debug label *)
  let label = if is_64bit then "range_check64" else "range_check" in
  let label = if is_compact then label ^ "_compact" else label in

  (* Create RangeCheck0 gate *)
  with_label label (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (RangeCheck0
                 { (* Current row *) v0
                 ; v0p0
                 ; v0p1
                 ; v0p2
                 ; v0p3
                 ; v0p4
                 ; v0p5
                 ; v0c0
                 ; v0c1
                 ; v0c2
                 ; v0c3
                 ; v0c4
                 ; v0c5
                 ; v0c6
                 ; v0c7
                 ; (* Coefficients *)
                   compact
                 } )
        } )

(* Helper to create RangeCheck1 gate *)
let range_check1 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(is_compact : bool = false) (v0 : Circuit.Field.t) (v1 : Circuit.Field.t)
    (v2 : Circuit.Field.t) (v12 : Circuit.Field.t) =
  let open Circuit in
  (* Define shorthand helpers *)
  let bits_le_to_field = Common.field_bits_le_to_field (module Circuit) in

  (* Create sublimbs - current row *)
  let v2c0 = bits_le_to_field v2 86 88 in
  let v2p0 = bits_le_to_field v2 74 86 in
  let v2p1 = bits_le_to_field v2 62 74 in
  let v2p2 = bits_le_to_field v2 50 62 in
  let v2p3 = bits_le_to_field v2 38 50 in
  let v2c1 = bits_le_to_field v2 36 38 in
  let v2c2 = bits_le_to_field v2 34 36 in
  let v2c3 = bits_le_to_field v2 32 34 in
  let v2c4 = bits_le_to_field v2 30 32 in
  let v2c5 = bits_le_to_field v2 28 30 in
  let v2c6 = bits_le_to_field v2 26 28 in
  let v2c7 = bits_le_to_field v2 24 26 in
  let v2c8 = bits_le_to_field v2 22 24 in

  (* Create sublimbs - next row *)
  let v2c9 = bits_le_to_field v2 20 22 in
  let v2c10 = bits_le_to_field v2 18 20 in
  let v2c11 = bits_le_to_field v2 16 18 in
  let v0p0 = bits_le_to_field v0 76 88 in
  let v0p1 = bits_le_to_field v0 64 76 in
  let v1p0 = bits_le_to_field v1 76 88 in
  let v1p1 = bits_le_to_field v1 64 76 in
  let v2c12 = bits_le_to_field v2 14 16 in
  let v2c13 = bits_le_to_field v2 12 14 in
  let v2c14 = bits_le_to_field v2 10 12 in
  let v2c15 = bits_le_to_field v2 8 10 in
  let v2c16 = bits_le_to_field v2 6 8 in
  let v2c17 = bits_le_to_field v2 4 6 in
  let v2c18 = bits_le_to_field v2 2 4 in
  let v2c19 = bits_le_to_field v2 0 2 in

  (* Prepare debug label *)
  let label =
    if is_compact then "multi_range_check_compact" else "multi_range_check"
  in

  (* Create RangeCheck0 gate *)
  with_label label (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (RangeCheck1
                 { (* Current row *) v2
                 ; v12
                 ; v2c0
                 ; v2p0
                 ; v2p1
                 ; v2p2
                 ; v2p3
                 ; v2c1
                 ; v2c2
                 ; v2c3
                 ; v2c4
                 ; v2c5
                 ; v2c6
                 ; v2c7
                 ; v2c8
                 ; (* Next row *) v2c9
                 ; v2c10
                 ; v2c11
                 ; v0p0
                 ; v0p1
                 ; v1p0
                 ; v1p1
                 ; v2c12
                 ; v2c13
                 ; v2c14
                 ; v2c15
                 ; v2c16
                 ; v2c17
                 ; v2c18
                 ; v2c19
                 } )
        } )

(* range-check gadget - checks v0 \in [0, 2^88) *)
let range_check (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v0 : Circuit.Field.t) =
  range_check0 (module Circuit) ~is_64bit:false ~is_compact:false v0

(* 64-bit range-check gadget - checks v0 \in [0, 2^64) *)
let range_check64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v0 : Circuit.Field.t) =
  range_check0 (module Circuit) ~is_64bit:true ~is_compact:false v0

(* 64-bit range-check gadget - checks v0 \in [0, 2^64) *)
let multi_range_check (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(is_compact : bool = false) (v0 : Circuit.Field.t)
    (v1 : Circuit.Field.t) (* TODO: change params to v10, v2*)
    (v2 : Circuit.Field.t) =
  let open Circuit in
  let v0, v1, v2, v12 =
    if is_compact then
      let v01 =
        exists Field.typ ~compute:(fun () ->
            let two_to_limb =
              Field.Constant.of_string "309485009821345068724781056"
            in
            let v0 = As_prover.read Field.typ v0 in
            let v1 = As_prover.read Field.typ v1 in
            let v1_scaled = Field.Constant.mul v1 two_to_limb in
            Field.Constant.add v0 v1_scaled )
      in
      (v2, v0, v1, v01)
    else (v0, v1, v2, Field.zero)
  in
  range_check0 (module Circuit) ~is_64bit:false ~is_compact:false v0 ;
  range_check0 (module Circuit) ~is_64bit:false ~is_compact v1 ;
  range_check1 (module Circuit) ~is_compact v0 v1 v2 v12

(*********)
(* Tests *)
(*********)

let%test_unit "range_check gadget" =
  Printf.printf "range_check gadget test\n" ;
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test range_check gadget *)
  let test_range_check base10 : bool =
    try
      let _proof_keypair, _proof =
        Runner.generate_and_verify_proof (fun () ->
            let open Runner.Impl in
            let value =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string base10 )
            in
            range_check (module Runner.Impl) value ;
            (* Padding *)
            Boolean.Assert.is_true (Field.equal value value) )
      in
      true
    with exn ->
      Format.eprintf "Error: %s@." (Exn.to_string exn) ;
      Printexc.print_backtrace Stdlib.stdout ;
      Stdlib.(flush stdout) ;
      false
  in

  (* Positive tests *)
  assert (Bool.equal (test_range_check "0") true) ;
  assert (Bool.equal (test_range_check "18446744073709551616") (* 2^64 *) true) ;
  assert (
    Bool.equal
      (test_range_check "309485009821345068724781055")
      (* 2^88 - 1 *)
      true ) ;

  (* Negative tests *)
  assert (
    Bool.equal (test_range_check "309485009821345068724781056") (* 2^88 *) false ) ;
  assert (
    Bool.equal
      (test_range_check
         "28948022309329048855892746252171976963317496166410141009864396001978282409984" )
      (* 2^254 *)
      false ) ;
  ()

let%test_unit "range_check64 gadget" =
  Printf.printf "range_check64 gadget test\n" ;
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test range_check64 gadget
   *   Input: value to be range checked in [0, 2^64)
   *)
  let test_range_check64 base10 : bool =
    try
      let _proof_keypair, _proof =
        Runner.generate_and_verify_proof (fun () ->
            let open Runner.Impl in
            let value =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string base10 )
            in
            range_check64 (module Runner.Impl) value ;
            (* Padding *)
            Boolean.Assert.is_true (Field.equal value value) )
      in
      true
    with exn ->
      Format.eprintf "Error: %s@." (Exn.to_string exn) ;
      Printexc.print_backtrace Stdlib.stdout ;
      Stdlib.(flush stdout) ;
      false
  in

  (* Positive tests *)
  assert (Bool.equal (test_range_check64 "0") true) ;
  assert (Bool.equal (test_range_check64 "4294967") true) ;
  assert (Bool.equal (test_range_check64 "18446744073709551615") true) ;
  (* 2^64 - 1 *)
  (* Negative tests *)
  assert (Bool.equal (test_range_check64 "18446744073709551616") false) ;
  (* 2^64 *)
  assert (
    Bool.equal
      (test_range_check64 "170141183460469231731687303715884105728")
      (* 2^127  *)
      false ) ;
  ()
