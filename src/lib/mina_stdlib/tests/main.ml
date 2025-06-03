(** Testing
    -------
    Component:  Mina stdlib
    Invocation: dune exec src/lib/mina_stdlib/tests/main.exe
    Subject:    Main test runner for mina_stdlib tests
 *)

(* Run all tests *)
let () =
  let open Alcotest in
  run "Time.Span.Stable.V1 JSON roundtrip"
    [ ( "basic roundtrip tests"
      , [ test_case "basic json roundtrip" `Quick
            Time_test.test_basic_json_roundtrip
        ; test_case "zero span roundtrip" `Quick
            Time_test.test_zero_span_roundtrip
        ; test_case "positive span roundtrip" `Quick
            Time_test.test_positive_span_roundtrip
        ; test_case "negative span roundtrip" `Quick
            Time_test.test_negative_span_roundtrip
        ; test_case "fraction span roundtrip" `Quick
            Time_test.test_fraction_span_roundtrip
        ; test_case "very small span roundtrip" `Quick
            Time_test.test_very_small_span_roundtrip
        ; test_case "large span roundtrip" `Quick
            Time_test.test_large_span_roundtrip
        ] )
    ; ( "error cases"
      , [ test_case "invalid json input" `Quick
            Time_test.test_invalid_json_input
        ; test_case "non-float json type" `Quick
            Time_test.test_non_float_json_type
        ] )
    ]
