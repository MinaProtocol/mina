(** Testing
    -------
    Component: Kimchi gadgets - Range check
    Subject: Testing range check gadgets
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/tests/test_range_check.exe *)

open Kimchi_gadgets
open Kimchi_gadgets_test_runner

let () =
  try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()

(** Test range_check64 gadget. Returns constraint system if satisfied. *)
let test_range_check64 ?cs base10 =
  let open Runner.Impl in
  let value = Common.field_of_base10 base10 in

  let make_circuit value =
    let value = exists Field.typ ~compute:(fun () -> value) in
    Range_check.bits64 value ;
    Boolean.Assert.is_true (Field.equal value value)
  in

  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () -> make_circuit value)
  in
  cs

(** Test multi_range_check gadget. Returns constraint system if satisfied. *)
let test_multi_range_check ?cs v0 v1 v2 =
  let open Runner.Impl in
  let v0 = Common.field_of_base10 v0 in
  let v1 = Common.field_of_base10 v1 in
  let v2 = Common.field_of_base10 v2 in

  let make_circuit v0 v1 v2 =
    let values =
      exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
          [| v0; v1; v2 |] )
    in
    Range_check.multi values.(0) values.(1) values.(2)
  in

  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () -> make_circuit v0 v1 v2)
  in
  cs

(** Test compact_multi_range_check gadget. *)
let test_compact_multi_range_check v01 v2 : unit =
  let open Runner.Impl in
  let v01 = Common.field_of_base10 v01 in
  let v2 = Common.field_of_base10 v2 in

  let make_circuit v01 v2 =
    let v01, v2 =
      exists Typ.(Field.typ * Field.typ) ~compute:(fun () -> (v01, v2))
    in
    Range_check.compact_multi v01 v2
  in

  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof (fun () -> make_circuit v01 v2)
  in

  let mutate_witness value =
    Field.Constant.(if equal zero value then value + one else value - one)
  in
  let v01 = mutate_witness v01 in
  let v2 = mutate_witness v2 in

  let _cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ~cs (fun () -> make_circuit v01 v2)
  in
  ()

(* range_check64 tests *)
let test_range_check64_positive () =
  let cs = test_range_check64 "0" in
  let _cs = test_range_check64 ~cs "4294967" in
  let _cs = test_range_check64 ~cs "18446744073709551615" in
  (* 2^64 - 1 *)
  ()

let test_range_check64_negative () =
  let cs = test_range_check64 "0" in
  Alcotest.(check bool)
    "2^64 should fail" true
    (Common.is_error (fun () ->
         test_range_check64 ~cs "18446744073709551616" (* 2^64 *) ) ) ;
  Alcotest.(check bool)
    "2^127 should fail" true
    (Common.is_error (fun () ->
         test_range_check64 ~cs "170141183460469231731687303715884105728"
         (* 2^127 *) ) )

(* multi_range_check tests *)
let test_multi_range_check_positive () =
  let cs = test_multi_range_check "0" "4294967" "309485009821345068724781055" in
  let _cs =
    test_multi_range_check ~cs "267475740839011166017999907"
      "120402749546803056196583080" "1159834292458813579124542"
  in
  let _cs =
    test_multi_range_check ~cs "309485009821345068724781055"
      "309485009821345068724781055" "309485009821345068724781055"
  in
  let _cs = test_multi_range_check ~cs "0" "0" "0" in
  ()

let test_multi_range_check_negative () =
  let cs = test_multi_range_check "0" "4294967" "309485009821345068724781055" in
  Alcotest.(check bool)
    "v2 out of range should fail" true
    (Common.is_error (fun () ->
         test_multi_range_check ~cs "0" "4294967" "309485009821345068724781056" )
    ) ;
  Alcotest.(check bool)
    "v1 out of range should fail" true
    (Common.is_error (fun () ->
         test_multi_range_check ~cs "0" "309485009821345068724781056"
           "309485009821345068724781055" ) ) ;
  Alcotest.(check bool)
    "v0 out of range should fail" true
    (Common.is_error (fun () ->
         test_multi_range_check ~cs "309485009821345068724781056" "4294967"
           "309485009821345068724781055" ) ) ;
  Alcotest.(check bool)
    "very large values should fail" true
    (Common.is_error (fun () ->
         test_multi_range_check ~cs
           "28948022309329048855892746252171976963317496166410141009864396001978282409984"
           "0170141183460469231731687303715884105728"
           "170141183460469231731687303715884105728" ) ) ;
  Alcotest.(check bool)
    "v2 very large should fail" true
    (Common.is_error (fun () ->
         test_multi_range_check ~cs "0" "0"
           "28948022309329048855892746252171976963317496166410141009864396001978282409984" )
    ) ;
  Alcotest.(check bool)
    "v0 very large should fail" true
    (Common.is_error (fun () ->
         test_multi_range_check ~cs "0170141183460469231731687303715884105728"
           "0"
           "28948022309329048855892746252171976963317496166410141009864396001978282409984" )
    )

(* compact_multi_range_check tests *)
let test_compact_multi_range_check_positive () =
  test_compact_multi_range_check "0" "0" ;
  test_compact_multi_range_check
    "95780971304118053647396689196894323976171195136475135" (* 2^176 - 1 *)
    "309485009821345068724781055"
(* 2^88 - 1 *)

let test_compact_multi_range_check_negative () =
  Alcotest.(check bool)
    "v01 very large should fail" true
    (Common.is_error (fun () ->
         test_compact_multi_range_check
           "28948022309329048855892746252171976963317496166410141009864396001978282409984"
           "0" ) ) ;
  Alcotest.(check bool)
    "v2 very large should fail" true
    (Common.is_error (fun () ->
         test_compact_multi_range_check "0"
           "28948022309329048855892746252171976963317496166410141009864396001978282409984" )
    ) ;
  Alcotest.(check bool)
    "v01 = 2^176 should fail" true
    (Common.is_error (fun () ->
         test_compact_multi_range_check
           "95780971304118053647396689196894323976171195136475136" (* 2^176 *)
           "309485009821345068724781055"
         (* 2^88 - 1 *) ) ) ;
  Alcotest.(check bool)
    "v2 = 2^88 should fail" true
    (Common.is_error (fun () ->
         test_compact_multi_range_check
           "95780971304118053647396689196894323976171195136475135"
           (* 2^176 - 1 *)
           "309485009821345068724781056"
         (* 2^88 *) ) )

let () =
  let open Alcotest in
  run "Range check gadgets"
    [ ( "range_check64"
      , [ test_case "positive tests" `Quick test_range_check64_positive
        ; test_case "negative tests" `Quick test_range_check64_negative
        ] )
    ; ( "multi_range_check"
      , [ test_case "positive tests" `Quick test_multi_range_check_positive
        ; test_case "negative tests" `Quick test_multi_range_check_negative
        ] )
    ; ( "compact_multi_range_check"
      , [ test_case "positive tests" `Quick
            test_compact_multi_range_check_positive
        ; test_case "negative tests" `Quick
            test_compact_multi_range_check_negative
        ] )
    ]
