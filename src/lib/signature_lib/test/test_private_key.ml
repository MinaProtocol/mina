open Core_kernel
open Signature_lib
open Base_quickcheck

let modulus_string =
  "28948022309329048855892746252171976963363056481941647379679742748393362948097"

let test_of_string_exn_zero () =
  let key = Private_key.of_string_exn "0" in
  Alcotest.(check bool)
    "Private key from string \"0\" should create valid key" true
    (Snark_params.Tick.Inner_curve.Scalar.equal key
       Snark_params.Tick.Inner_curve.Scalar.zero )

let test_of_string_exn_one () =
  let key = Private_key.of_string_exn "1" in
  Alcotest.(check bool)
    "Private key from string \"1\" should create valid key" true
    (Snark_params.Tick.Inner_curve.Scalar.equal key
       Snark_params.Tick.Inner_curve.Scalar.one )

let test_of_string_exn_small_values () =
  let gen = Generator.int_inclusive 1 1000000 in
  let test_values =
    List.init 5 ~f:(fun _ -> Quickcheck.random_value gen |> Int.to_string)
  in
  List.iter test_values ~f:(fun s ->
      let key = Private_key.of_string_exn s in
      let expected = Snark_params.Tick.Inner_curve.Scalar.of_string s in
      Alcotest.(check bool)
        ("Private key from string \"" ^ s ^ "\" should match expected")
        true
        (Snark_params.Tick.Inner_curve.Scalar.equal key expected) )

let test_of_string_exn_modulus_minus_one () =
  let modulus_minus_one =
    Bignum_bigint.(modulus_string |> of_string |> pred |> to_string)
  in
  let key = Private_key.of_string_exn modulus_minus_one in
  let expected =
    Snark_params.Tick.Inner_curve.Scalar.of_string modulus_minus_one
  in
  Alcotest.(check bool)
    "Private key from string (modulus - 1) should create valid key" true
    (Snark_params.Tick.Inner_curve.Scalar.equal key expected)

let test_of_string_exn_values_exceeding_modulus () =
  (* Test with various values >= modulus - should raise exceptions *)
  let modulus = Bignum_bigint.of_string modulus_string in
  let modulus_plus_one = Bignum_bigint.(modulus |> succ |> to_string) in

  (* Generate random offsets to add to modulus *)
  let offset_gen = Generator.int_inclusive 1 1000000 in
  let random_offsets =
    List.init 3 ~f:(fun _ -> Quickcheck.random_value offset_gen)
  in
  let random_values =
    List.map random_offsets ~f:(fun offset ->
        Bignum_bigint.(modulus + of_int offset |> to_string) )
  in

  (* Include fixed test cases and random cases *)
  let test_values = modulus_string :: modulus_plus_one :: random_values in

  List.iter test_values ~f:(fun s ->
      try
        let _key = Private_key.of_string_exn s in
        Alcotest.fail ("Value >= modulus " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Value >= modulus " ^ s ^ " raises exception")
          true true )

let test_of_string_exn_random_values () =
  (* Test with randomly generated values less than modulus *)
  let modulus = Bignum_bigint.of_string modulus_string in
  let offset_gen = Generator.int_inclusive 1 10000000 in
  let random_values =
    List.init 5 ~f:(fun _ ->
        let random_offset = Quickcheck.random_value offset_gen in
        Bignum_bigint.(modulus - of_int random_offset |> to_string) )
  in
  List.iter random_values ~f:(fun s ->
      let key = Private_key.of_string_exn s in
      let expected = Snark_params.Tick.Inner_curve.Scalar.of_string s in
      Alcotest.(check bool)
        ("Private key from random string should match expected for " ^ s)
        true
        (Snark_params.Tick.Inner_curve.Scalar.equal key expected) )

let test_of_string_exn_edge_case_empty () =
  try
    let _key = Private_key.of_string_exn "" in
    Alcotest.fail "Empty string should raise an exception"
  with _ -> Alcotest.(check bool) "Empty string raises exception" true true

let test_of_string_exn_edge_case_invalid () =
  (* Test edge case: invalid string *)
  try
    let _key = Private_key.of_string_exn "not_a_number" in
    Alcotest.fail "Invalid string should raise an exception"
  with _ -> Alcotest.(check bool) "Invalid string raises exception" true true

let test_of_string_exn_negative_values () =
  (* Test negative values - should raise exceptions *)
  let gen = Generator.int_inclusive 1 1000000000 in
  let negative_values =
    List.init 5 ~f:(fun _ ->
        let random_negative = Quickcheck.random_value gen in
        "-" ^ Int.to_string random_negative )
  in
  List.iter negative_values ~f:(fun s ->
      try
        let _key = Private_key.of_string_exn s in
        Alcotest.fail ("Negative value " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Negative value " ^ s ^ " raises exception")
          true true )

let test_of_string_exn_hexadecimal_values () =
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
        let _key = Private_key.of_string_exn s in
        Alcotest.fail ("Hexadecimal value " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Hexadecimal value " ^ s ^ " raises exception")
          true true )

let test_of_string_exn_mixed_invalid_formats () =
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
        let _key = Private_key.of_string_exn s in
        Alcotest.fail ("Invalid format " ^ s ^ " should raise an exception")
      with _ ->
        Alcotest.(check bool)
          ("Invalid format " ^ s ^ " raises exception")
          true true )

let test_to_string_basic () =
  (* Test basic to_string functionality *)
  let gen = Generator.int_inclusive 1 1000000 in
  let random_values =
    List.init 5 ~f:(fun _ -> Quickcheck.random_value gen |> Int.to_string)
  in
  let test_values = "0" :: "1" :: random_values in
  List.iter test_values ~f:(fun s ->
      let key = Private_key.of_string_exn s in
      let result = Private_key.to_string key in
      Alcotest.(check string)
        ("to_string should return correct value for " ^ s)
        s result )

let test_to_string_large_values () =
  (* Test to_string with random large values *)
  let modulus = Bignum_bigint.of_string modulus_string in
  let modulus_minus_one = Bignum_bigint.(modulus |> pred |> to_string) in
  let offset_gen = Generator.int_inclusive 1000000 100000000 in
  let random_large_values =
    List.init 4 ~f:(fun _ ->
        let random_offset = Quickcheck.random_value offset_gen in
        Bignum_bigint.(modulus - of_int random_offset |> to_string) )
  in
  let large_values = modulus_minus_one :: random_large_values in
  List.iter large_values ~f:(fun s ->
      let key = Private_key.of_string_exn s in
      let result = Private_key.to_string key in
      Alcotest.(check string)
        ("to_string should return correct value for large number " ^ s)
        s result )

let test_roundtrip_of_string_exn_to_string () =
  (* Test that of_string_exn and to_string are inverse functions *)
  let modulus = Bignum_bigint.of_string modulus_string in
  let small_gen = Generator.int_inclusive 1 1000000 in
  let small_randoms =
    List.init 3 ~f:(fun _ -> Quickcheck.random_value small_gen |> Int.to_string)
  in
  let large_gen = Generator.int_inclusive 1000 10000000 in
  let large_randoms =
    List.init 3 ~f:(fun _ ->
        let random_offset = Quickcheck.random_value large_gen in
        Bignum_bigint.(modulus - of_int random_offset |> to_string) )
  in
  let test_values = [ "0"; "1" ] @ small_randoms @ large_randoms in
  List.iter test_values ~f:(fun original ->
      let key = Private_key.of_string_exn original in
      let roundtrip = Private_key.to_string key in
      Alcotest.(check string)
        ( "Roundtrip of_string_exn -> to_string should preserve value for "
        ^ original )
        original roundtrip )

let test_roundtrip_to_string_of_string_exn () =
  (* Test that to_string -> of_string_exn is also inverse for generated keys *)
  let randoms =
    List.init 5 ~f:(fun _ ->
        Quickcheck.random_value (Generator.int_inclusive 1 10000000)
        |> Int.to_string |> Private_key.of_string_exn )
  in
  List.iteri randoms ~f:(fun i key ->
      let str_repr = Private_key.to_string key in
      let roundtrip_key = Private_key.of_string_exn str_repr in
      Alcotest.(check bool)
        ( "Roundtrip to_string -> of_string_exn should preserve key "
        ^ Int.to_string i )
        true
        (Snark_params.Tick.Inner_curve.Scalar.equal key roundtrip_key) )

let test_to_string_modulus_minus_one () =
  (* Test to_string with the largest valid value *)
  let modulus_minus_one =
    Bignum_bigint.(modulus_string |> of_string |> pred |> to_string)
  in
  let key = Private_key.of_string_exn modulus_minus_one in
  let result = Private_key.to_string key in
  Alcotest.(check string)
    "to_string should handle modulus - 1 correctly" modulus_minus_one result

let () =
  let open Alcotest in
  run "Private_key string conversion tests"
    [ ( "Basic value tests"
      , [ test_case "of_string_exn with zero" `Quick test_of_string_exn_zero
        ; test_case "of_string_exn with one" `Quick test_of_string_exn_one
        ; test_case "of_string_exn with small values" `Quick
            test_of_string_exn_small_values
        ] )
    ; ( "Modulus boundary tests"
      , [ test_case "of_string_exn with modulus - 1" `Quick
            test_of_string_exn_modulus_minus_one
        ; test_case
            "of_string_exn with values >= modulus (should raise exception)"
            `Quick test_of_string_exn_values_exceeding_modulus
        ] )
    ; ( "Random and edge cases"
      , [ test_case "of_string_exn with random large values" `Quick
            test_of_string_exn_random_values
        ; test_case "of_string_exn with empty string" `Quick
            test_of_string_exn_edge_case_empty
        ; test_case "of_string_exn with invalid string" `Quick
            test_of_string_exn_edge_case_invalid
        ] )
    ; ( "Invalid format tests"
      , [ test_case "of_string_exn with negative values" `Quick
            test_of_string_exn_negative_values
        ; test_case "of_string_exn with hexadecimal values" `Quick
            test_of_string_exn_hexadecimal_values
        ; test_case "of_string_exn with mixed invalid formats" `Quick
            test_of_string_exn_mixed_invalid_formats
        ] )
    ; ( "to_string tests"
      , [ test_case "to_string with basic values" `Quick test_to_string_basic
        ; test_case "to_string with large values" `Quick
            test_to_string_large_values
        ; test_case "to_string with modulus - 1" `Quick
            test_to_string_modulus_minus_one
        ] )
    ; ( "Roundtrip tests"
      , [ test_case "of_string_exn -> to_string roundtrip" `Quick
            test_roundtrip_of_string_exn_to_string
        ; test_case "to_string -> of_string_exn roundtrip" `Quick
            test_roundtrip_to_string_of_string_exn
        ] )
    ]
