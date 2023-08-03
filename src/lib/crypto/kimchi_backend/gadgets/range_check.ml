open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let tests_enabled = false

(* Helper to create RangeCheck0 gate, configured in various ways
 *     - is_64bit   : create 64-bit range check
 *     - is_compact : compact limbs mode (only used by compact multi-range-check)
 *)
let range_check0 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ~(label : string) ?(is_compact : bool = false) (v0 : Circuit.Field.t)
    (v0p0 : Circuit.Field.t) (v0p1 : Circuit.Field.t) =
  let open Circuit in
  (* Define shorthand helper *)
  let of_bits =
    Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
  in

  (* Sanity check v0p0 and v1p1 correspond to the correct bits of v0 *)
  as_prover (fun () ->
      let open Circuit.Field in
      let v0p0_expected = of_bits v0 76 88 in
      let v0p1_expected = of_bits v0 64 76 in

      Assert.equal v0p0 v0p0_expected ;
      Assert.equal v0p1 v0p1_expected ) ;

  (* Create sublimbs *)
  let v0p2 = of_bits v0 52 64 in
  let v0p3 = of_bits v0 40 52 in
  let v0p4 = of_bits v0 28 40 in
  let v0p5 = of_bits v0 16 28 in
  let v0c0 = of_bits v0 14 16 in
  let v0c1 = of_bits v0 12 14 in
  let v0c2 = of_bits v0 10 12 in
  let v0c3 = of_bits v0 8 10 in
  let v0c4 = of_bits v0 6 8 in
  let v0c5 = of_bits v0 4 6 in
  let v0c6 = of_bits v0 2 4 in
  let v0c7 = of_bits v0 0 2 in

  (* Set up compact mode coefficient *)
  let compact =
    if is_compact then Field.Constant.one else Field.Constant.zero
  in

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
    ~(label : string) (v0p0 : Circuit.Field.t) (v0p1 : Circuit.Field.t)
    (v1p0 : Circuit.Field.t) (v1p1 : Circuit.Field.t) (v2 : Circuit.Field.t)
    (v12 : Circuit.Field.t) =
  let open Circuit in
  (* Define shorthand helper *)
  let of_bits =
    Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
  in

  (* Create sublimbs - current row *)
  let v2c0 = of_bits v2 86 88 in
  let v2p0 = of_bits v2 74 86 in
  let v2p1 = of_bits v2 62 74 in
  let v2p2 = of_bits v2 50 62 in
  let v2p3 = of_bits v2 38 50 in
  let v2c1 = of_bits v2 36 38 in
  let v2c2 = of_bits v2 34 36 in
  let v2c3 = of_bits v2 32 34 in
  let v2c4 = of_bits v2 30 32 in
  let v2c5 = of_bits v2 28 30 in
  let v2c6 = of_bits v2 26 28 in
  let v2c7 = of_bits v2 24 26 in
  let v2c8 = of_bits v2 22 24 in

  (* Create sublimbs - next row *)
  let v2c9 = of_bits v2 20 22 in
  let v2c10 = of_bits v2 18 20 in
  let v2c11 = of_bits v2 16 18 in
  let v2c12 = of_bits v2 14 16 in
  let v2c13 = of_bits v2 12 14 in
  let v2c14 = of_bits v2 10 12 in
  let v2c15 = of_bits v2 8 10 in
  let v2c16 = of_bits v2 6 8 in
  let v2c17 = of_bits v2 4 6 in
  let v2c18 = of_bits v2 2 4 in
  let v2c19 = of_bits v2 0 2 in

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

(* 64-bit range-check gadget - checks v0 \in [0, 2^64) *)
let bits64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v0 : Circuit.Field.t) =
  range_check0
    (module Circuit)
    ~label:"range_check64" ~is_compact:false v0 Circuit.Field.zero
    Circuit.Field.zero

(* multi-range-check gadget - checks v0,v1,v2 \in [0, 2^88) *)
let multi (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v0 : Circuit.Field.t) (v1 : Circuit.Field.t) (v2 : Circuit.Field.t) =
  let open Circuit in
  let of_bits =
    Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
  in
  let v0p0 = of_bits v0 76 88 in
  let v0p1 = of_bits v0 64 76 in
  range_check0
    (module Circuit)
    ~label:"multi_range_check" ~is_compact:false v0 v0p0 v0p1 ;
  let v1p0 = of_bits v1 76 88 in
  let v1p1 = of_bits v1 64 76 in
  range_check0
    (module Circuit)
    ~label:"multi_range_check" ~is_compact:false v1 v1p0 v1p1 ;
  let zero = exists Field.typ ~compute:(fun () -> Field.Constant.zero) in
  range_check1
    (module Circuit)
    ~label:"multi_range_check" v0p0 v0p1 v1p0 v1p1 v2 zero

(* compact multi-range-check gadget - checks
 *     - v0,v1,v2 \in [0, 2^88)
 *     - v01 = v0 + 2^88 * v1
 *)
let compact_multi (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v01 : Circuit.Field.t) (v2 : Circuit.Field.t) :
    Circuit.Field.t * Circuit.Field.t =
  let open Circuit in
  (* Set up helper *)
  let bignum_bigint_to_field = Common.bignum_bigint_to_field (module Circuit) in
  (* Prepare range-check values *)
  let v1, v0 =
    exists
      Typ.(Field.typ * Field.typ)
      ~compute:(fun () ->
        (* Decompose v0 and v1 from v01 = 2^L * v1 + v0 *)
        let v01 =
          Common.field_to_bignum_bigint
            (module Circuit)
            (As_prover.read Field.typ v01)
        in
        let v1, v0 = Common.(bignum_bigint_div_rem v01 two_to_limb) in
        (bignum_bigint_to_field v1, bignum_bigint_to_field v0) )
  in
  let of_bits =
    Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
  in
  let v2p0 = of_bits v2 76 88 in
  let v2p1 = of_bits v2 64 76 in
  range_check0
    (module Circuit)
    ~label:"compact_multi_range_check" ~is_compact:false v2 v2p0 v2p1 ;
  let v0p0 = of_bits v0 76 88 in
  let v0p1 = of_bits v0 64 76 in
  range_check0
    (module Circuit)
    ~label:"compact_multi_range_check" ~is_compact:true v0 v0p0 v0p1 ;
  range_check1
    (module Circuit)
    ~label:"compact_multi_range_check" v2p0 v2p1 v0p0 v0p1 v1 v01 ;

  (v0, v1)

(*********)
(* Tests *)
(*********)

let%test_unit "range_check64 gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test range_check64 gadget
     *   Input: value to be range checked in [0, 2^64)
     *)
    let test_range_check64 ?cs base10 =
      let open Runner.Impl in
      let value = Common.field_of_base10 (module Runner.Impl) base10 in

      let make_circuit value =
        (* Circuit definition *)
        let value = exists Field.typ ~compute:(fun () -> value) in
        bits64 (module Runner.Impl) value ;
        (* Padding *)
        Boolean.Assert.is_true (Field.equal value value)
      in

      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () -> make_circuit value)
      in
      cs
    in

    (* Positive tests *)
    let cs = test_range_check64 "0" in
    let _cs = test_range_check64 ~cs "4294967" in
    let _cs = test_range_check64 ~cs "18446744073709551615" in
    (* 2^64 - 1 *)
    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          test_range_check64 ~cs "18446744073709551616" (* 2^64 *) ) ) ;
    assert (
      Common.is_error (fun () ->
          test_range_check64 ~cs "170141183460469231731687303715884105728"
          (* 2^127  *) ) ) ) ;
  ()

let%test_unit "multi_range_check gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test multi_range_check gadget *)
    let test_multi_range_check ?cs v0 v1 v2 =
      let open Runner.Impl in
      let v0 = Common.field_of_base10 (module Runner.Impl) v0 in
      let v1 = Common.field_of_base10 (module Runner.Impl) v1 in
      let v2 = Common.field_of_base10 (module Runner.Impl) v2 in

      let make_circuit v0 v1 v2 =
        (* Circuit definition *)
        let values =
          exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
              [| v0; v1; v2 |] )
        in
        multi (module Runner.Impl) values.(0) values.(1) values.(2)
      in

      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () -> make_circuit v0 v1 v2)
      in

      cs
    in

    (* Positive tests *)
    let cs =
      test_multi_range_check "0" "4294967" "309485009821345068724781055"
    in
    let _cs =
      test_multi_range_check ~cs "267475740839011166017999907"
        "120402749546803056196583080" "1159834292458813579124542"
    in
    let _cs =
      test_multi_range_check ~cs "309485009821345068724781055"
        "309485009821345068724781055" "309485009821345068724781055"
    in
    let _cs = test_multi_range_check ~cs "0" "0" "0" in
    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          test_multi_range_check ~cs "0" "4294967" "309485009821345068724781056" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_multi_range_check ~cs "0" "309485009821345068724781056"
            "309485009821345068724781055" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_multi_range_check ~cs "309485009821345068724781056" "4294967"
            "309485009821345068724781055" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_multi_range_check ~cs
            "28948022309329048855892746252171976963317496166410141009864396001978282409984"
            "0170141183460469231731687303715884105728"
            "170141183460469231731687303715884105728" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_multi_range_check ~cs "0" "0"
            "28948022309329048855892746252171976963317496166410141009864396001978282409984" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_multi_range_check ~cs "0170141183460469231731687303715884105728"
            "0"
            "28948022309329048855892746252171976963317496166410141009864396001978282409984" ) )
    ) ;
  ()

let%test_unit "compact_multi_range_check gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test compact_multi_range_check gadget *)
    let test_compact_multi_range_check v01 v2 : unit =
      let open Runner.Impl in
      let v01 = Common.field_of_base10 (module Runner.Impl) v01 in
      let v2 = Common.field_of_base10 (module Runner.Impl) v2 in

      let make_circuit v01 v2 =
        (* Circuit definition *)
        let v01, v2 =
          exists Typ.(Field.typ * Field.typ) ~compute:(fun () -> (v01, v2))
        in
        let _v0, _v1 = compact_multi (module Runner.Impl) v01 v2 in
        ()
      in

      (* Generate and verify first proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof (fun () -> make_circuit v01 v2)
      in

      (* Set up another witness *)
      let mutate_witness value =
        Field.Constant.(if equal zero value then value + one else value - one)
      in
      let v01 = mutate_witness v01 in
      let v2 = mutate_witness v2 in

      (* Generate and verify second proof, reusing constraint system *)
      let _cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ~cs (fun () -> make_circuit v01 v2)
      in

      ()
    in

    (* Positive tests *)
    test_compact_multi_range_check "0" "0" ;
    test_compact_multi_range_check
      "95780971304118053647396689196894323976171195136475135" (* 2^176 - 1 *)
      "309485009821345068724781055"
    (* 2^88 - 1 *) ;
    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          test_compact_multi_range_check
            "28948022309329048855892746252171976963317496166410141009864396001978282409984"
            "0" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_compact_multi_range_check "0"
            "28948022309329048855892746252171976963317496166410141009864396001978282409984" ) ) ;
    assert (
      Common.is_error (fun () ->
          test_compact_multi_range_check
            "95780971304118053647396689196894323976171195136475136" (* 2^176 *)
            "309485009821345068724781055" ) (* 2^88 - 1 *) ) ;
    assert (
      Common.is_error (fun () ->
          test_compact_multi_range_check
            "95780971304118053647396689196894323976171195136475135"
            (* 2^176 - 1 *)
            "309485009821345068724781056" ) (* 2^88 *) ) ) ;
  ()
