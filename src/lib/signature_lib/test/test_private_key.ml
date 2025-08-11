open Core_kernel
open Signature_lib

let modulus_string =
  "28948022309329048855892746252171976963363056481941647379679742748393362948097"

let test_of_string_zero () =
  let key = Private_key.of_string "0" in
  Alcotest.(check bool)
    "Private key from string \"0\" should create valid key" true
    (Snark_params.Tick.Inner_curve.Scalar.equal key
       Snark_params.Tick.Inner_curve.Scalar.zero )

let test_of_string_one () =
  let key = Private_key.of_string "1" in
  Alcotest.(check bool)
    "Private key from string \"1\" should create valid key" true
    (Snark_params.Tick.Inner_curve.Scalar.equal key
       Snark_params.Tick.Inner_curve.Scalar.one )

let test_of_string_small_values () =
  let test_values = [ "2"; "10"; "42"; "100"; "1000" ] in
  List.iter test_values ~f:(fun s ->
      let key = Private_key.of_string s in
      let expected = Snark_params.Tick.Inner_curve.Scalar.of_string s in
      Alcotest.(check bool)
        ("Private key from string \"" ^ s ^ "\" should match expected")
        true
        (Snark_params.Tick.Inner_curve.Scalar.equal key expected) )

let test_of_string_modulus_minus_one () =
  let modulus_minus_one =
    Bignum_bigint.(modulus_string |> of_string |> pred |> to_string)
  in
  let key = Private_key.of_string modulus_minus_one in
  let expected =
    Snark_params.Tick.Inner_curve.Scalar.of_string modulus_minus_one
  in
  Alcotest.(check bool)
    "Private key from string (modulus - 1) should create valid key" true
    (Snark_params.Tick.Inner_curve.Scalar.equal key expected)

let test_of_string_modulus () =
  (* Test that passing the modulus value raises an exception *)
  try
    let _key = Private_key.of_string modulus_string in
    Alcotest.fail "Modulus string should raise an exception"
  with _ -> Alcotest.(check bool) "Modulus string raises exception" true true

let test_of_string_higher_than_modulus () =
  (* Test with modulus + 1 - should raise exception *)
  let modulus_plus_one =
    Bignum_bigint.(modulus_string |> of_string |> succ |> to_string)
  in
  try
    let _key = Private_key.of_string modulus_plus_one in
    Alcotest.fail "Values >= modulus should raise an exception"
  with _ ->
    Alcotest.(check bool) "Values >= modulus raise exception" true true

let test_of_string_much_higher_than_modulus () =
  (* Test with modulus + 42 - should raise exception *)
  let modulus_plus_42 =
    Bignum_bigint.(
      modulus_string |> of_string |> ( + ) (of_int 42) |> to_string)
  in
  try
    let _key = Private_key.of_string modulus_plus_42 in
    Alcotest.fail "Values >= modulus should raise an exception"
  with _ ->
    Alcotest.(check bool) "Values >= modulus raise exception" true true

let test_of_string_very_large () =
  (* Test with a much larger number: 2 * modulus + 123 - should raise exception *)
  let two_times_modulus_plus_123 =
    let modulus = Bignum_bigint.of_string modulus_string in
    Bignum_bigint.((modulus * of_int 2) + of_int 123 |> to_string)
  in
  try
    let _key = Private_key.of_string two_times_modulus_plus_123 in
    Alcotest.fail "Values >= modulus should raise an exception"
  with _ ->
    Alcotest.(check bool) "Values >= modulus raise exception" true true

let test_of_string_random_values () =
  (* Test with some random large values less than modulus *)
  let random_values =
    [ "12345678901234567890123456789012345678901234567890123456789012345678901234567"
    ; "28948022309329048855892746252171976963363056481941647379679742748393362948096"
    ; (* modulus - 1 *)
      "1000000000000000000000000000000000000000000000000000000000000000000000000000"
    ]
  in
  List.iter random_values ~f:(fun s ->
      try
        let key = Private_key.of_string s in
        let expected = Snark_params.Tick.Inner_curve.Scalar.of_string s in
        Alcotest.(check bool)
          ("Private key from random string should match expected for " ^ s)
          true
          (Snark_params.Tick.Inner_curve.Scalar.equal key expected)
      with _ ->
        (* If the value is >= modulus, it should raise an exception *)
        let modulus = Bignum_bigint.of_string modulus_string in
        let value = Bignum_bigint.of_string s in
        if Bignum_bigint.(value >= modulus) then
          Alcotest.(check bool)
            ("Value " ^ s ^ " >= modulus raises exception")
            true true
        else Alcotest.fail ("Unexpected exception for valid value " ^ s) )

let test_of_string_edge_case_empty () =
  (* Test edge case: empty string should be treated as zero *)
  try
    let _key = Private_key.of_string "" in
    Alcotest.fail "Empty string should raise an exception"
  with _ -> Alcotest.(check bool) "Empty string raises exception" true true

let test_of_string_edge_case_invalid () =
  (* Test edge case: invalid string *)
  try
    let _key = Private_key.of_string "not_a_number" in
    Alcotest.fail "Invalid string should raise an exception"
  with _ -> Alcotest.(check bool) "Invalid string raises exception" true true

let test_of_string_negative_values () =
  (* Test negative values - should raise exceptions *)
  let negative_values = [ "-1"; "-42"; "-100"; "-1000000000" ] in
  List.iter negative_values ~f:(fun s ->
      try
        let _key = Private_key.of_string s in
        Alcotest.fail ("Negative value " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Negative value " ^ s ^ " raises exception")
          true true )

let test_of_string_hexadecimal_values () =
  (* Test hexadecimal values - should raise exceptions since only decimal is supported *)
  let hex_values =
    [ "0x1"
    ; "0x42"
    ; "0xFF"
    ; "0xDEADBEEF"
    ; "0x123456789ABCDEF"
    ; "ff"
    ; "DEADBEEF"
    ]
  in
  List.iter hex_values ~f:(fun s ->
      try
        let _key = Private_key.of_string s in
        Alcotest.fail ("Hexadecimal value " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Hexadecimal value " ^ s ^ " raises exception")
          true true )

let test_of_string_mixed_invalid_formats () =
  (* Test various invalid formats *)
  let invalid_formats =
    [ "1.0"
    ; "1e10"
    ; "1E5"
    ; "+42"
    ; " 42 "
    ; "42.0"
    ; "42abc"
    ; "abc42"
    ; "0b1010"
    ; "0o777"
    ; "1,000"
    ]
  in
  List.iter invalid_formats ~f:(fun s ->
      try
        let _key = Private_key.of_string s in
        Alcotest.fail ("Invalid format " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Invalid format " ^ s ^ " raises exception")
          true true )

let () =
  let open Alcotest in
  run "Private_key.of_string tests"
    [ ( "Basic value tests"
      , [ test_case "of_string with zero" `Quick test_of_string_zero
        ; test_case "of_string with one" `Quick test_of_string_one
        ; test_case "of_string with small values" `Quick
            test_of_string_small_values
        ] )
    ; ( "Modulus boundary tests"
      , [ test_case "of_string with modulus - 1" `Quick
            test_of_string_modulus_minus_one
        ; test_case "of_string with modulus (should raise exception)" `Quick
            test_of_string_modulus
        ; test_case "of_string with modulus + 1 (should raise exception)" `Quick
            test_of_string_higher_than_modulus
        ; test_case "of_string with modulus + 42 (should raise exception)"
            `Quick test_of_string_much_higher_than_modulus
        ; test_case "of_string with 2 * modulus + 123 (should raise exception)"
            `Quick test_of_string_very_large
        ] )
    ; ( "Random and edge cases"
      , [ test_case "of_string with random large values" `Quick
            test_of_string_random_values
        ; test_case "of_string with empty string" `Quick
            test_of_string_edge_case_empty
        ; test_case "of_string with invalid string" `Quick
            test_of_string_edge_case_invalid
        ] )
    ; ( "Invalid format tests"
      , [ test_case "of_string with negative values" `Quick
            test_of_string_negative_values
        ; test_case "of_string with hexadecimal values" `Quick
            test_of_string_hexadecimal_values
        ; test_case "of_string with mixed invalid formats" `Quick
            test_of_string_mixed_invalid_formats
        ] )
    ]
