open Core_kernel

module Make (Field : Kimchi_pasta_snarky_backend.Field.S_with_version) = struct
  let test_field_sexp_round_trip () =
    let t = Field.random () in
    Alcotest.(check bool)
      "Sexp round trip" true
      (Field.equal t (Field.t_of_sexp (Field.sexp_of_t t)))

  let test_field_bin_io_round_trip () =
    let t = Field.random () in
    Alcotest.(check bool)
      "Bin_io round trip" true
      (Field.equal t
         (Binable.of_string
            (module Field.Stable.Latest)
            (Binable.to_string (module Field.Stable.Latest) t) ) )

  let test_field_of_bits_to_bits () =
    let x = Field.random () in
    Alcotest.(check bool)
      "of_bits to_bits round trip" true
      (Field.equal x (Field.of_bits (Field.to_bits x)))

  let test_field_to_bits_of_bits () =
    (* Generate random bits with one less than size_in_bits *)
    let bs = List.init (Field.size_in_bits - 1) ~f:(fun _ -> Random.bool ()) in
    (* Append false as the last bit *)
    let expected_bits = bs @ [ false ] in
    let result_bits = Field.to_bits (Field.of_bits bs) in
    Alcotest.(check (list bool))
      "to_bits of_bits equivalence" expected_bits result_bits

  let test_field_of_yojson_hex () =
    let t = Field.random () in
    let hex_json = Field.to_yojson t in
    match Field.of_yojson hex_json with
    | Ok t' ->
        Alcotest.(check bool)
          "of_yojson works with hex string" true (Field.equal t t')
    | Error msg ->
        Alcotest.fail (Printf.sprintf "Failed to parse hex JSON: %s" msg)

  let test_field_of_yojson_decimal () =
    let t = Field.random () in
    let bigint = Field.to_bigint t in
    let decimal_str = Field.Bigint.to_string bigint in
    let decimal_json = `String decimal_str in
    match Field.of_yojson decimal_json with
    | Ok t' ->
        Alcotest.(check bool)
          "of_yojson works with decimal string" true (Field.equal t t')
    | Error msg ->
        Alcotest.fail (Printf.sprintf "Failed to parse decimal JSON: %s" msg)

  let test_field_of_yojson_invalid_type () =
    match Field.of_yojson (`Int 42) with
    | Ok _ ->
        Alcotest.fail "Should not parse non-string JSON"
    | Error _ ->
        Alcotest.(check bool)
          "of_yojson should fail with non-string JSON" true true

  let test_field_of_yojson_zero_decimal () =
    (* Test parsing "0" as decimal string *)
    match Field.of_yojson (`String "0") with
    | Ok result ->
        Alcotest.(check bool)
          "Decimal 0 should equal Field.zero" true
          (Field.equal result Field.zero)
    | Error msg ->
        Alcotest.fail (Printf.sprintf "Failed to parse 0 as decimal: %s" msg)

  let test_field_of_yojson_one_decimal () =
    (* Test parsing "1" as decimal string *)
    match Field.of_yojson (`String "1") with
    | Ok result ->
        Alcotest.(check bool)
          "Decimal 1 should equal Field.one" true
          (Field.equal result Field.one)
    | Error msg ->
        Alcotest.fail (Printf.sprintf "Failed to parse 1 as decimal: %s" msg)

  let test_field_of_yojson_42_decimal () =
    (* Test parsing "42" as decimal string *)
    match Field.of_yojson (`String "42") with
    | Ok result ->
        Alcotest.(check bool)
          "Decimal 42 should equal Field.one" true
          (Field.equal result (Field.of_int 42))
    | Error msg ->
        Alcotest.fail (Printf.sprintf "Failed to parse 42 as decimal: %s" msg)

  let test_field_of_yojson_modulus_decimal () =
    (* Test parsing the modulus as decimal string *)
    let modulus = Field.size in
    let modulus_str = Field.Bigint.to_string modulus in
    try
      (* Attempt to parse the modulus as decimal string *)
      match Field.of_yojson (`String modulus_str) with
      | Ok _result ->
          Alcotest.(fail "Parsing modulus as decimal should fail")
      | Error _msg ->
          Alcotest.(check bool)
            "Parsing modulus as decimal should fail" true true
    with
    | Failure _ ->
        (* If an exception is raised, it means the parsing failed as expected *)
        (* for the pasta curves, an exception Failure is raised *)
        Alcotest.(check bool) "Parsing modulus as decimal should fail" true true
    | _ ->
        Alcotest.(fail "Unexpected exception")
end

module Pallas = Make (Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field)
module Vesta = Make (Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field)

let () =
  let open Alcotest in
  run "Field Tests"
    [ ( "Pallas"
      , [ test_case "sexp round trip" `Quick Pallas.test_field_sexp_round_trip
        ; test_case "bin_io round trip" `Quick
            Pallas.test_field_bin_io_round_trip
        ; test_case "of_bits to_bits" `Quick Pallas.test_field_of_bits_to_bits
        ; test_case "to_bits of_bits" `Quick Pallas.test_field_to_bits_of_bits
        ; test_case "of_yojson hex" `Quick Pallas.test_field_of_yojson_hex
        ; test_case "of_yojson decimal" `Quick
            Pallas.test_field_of_yojson_decimal
        ; test_case "of_yojson invalid type" `Quick
            Pallas.test_field_of_yojson_invalid_type
        ; test_case "of_yojson zero decimal" `Quick
            Pallas.test_field_of_yojson_zero_decimal
        ; test_case "of_yojson one decimal" `Quick
            Pallas.test_field_of_yojson_one_decimal
        ; test_case "of_yojson 42 decimal" `Quick
            Pallas.test_field_of_yojson_42_decimal
        ; test_case "of_yojson modulus decimal" `Quick
            Pallas.test_field_of_yojson_modulus_decimal
        ] )
    ; ( "Vesta"
      , [ test_case "sexp round trip" `Quick Vesta.test_field_sexp_round_trip
        ; test_case "bin_io round trip" `Quick
            Vesta.test_field_bin_io_round_trip
        ; test_case "of_bits to_bits" `Quick Vesta.test_field_of_bits_to_bits
        ; test_case "to_bits of_bits" `Quick Vesta.test_field_to_bits_of_bits
        ; test_case "of_yojson hex" `Quick Vesta.test_field_of_yojson_hex
        ; test_case "of_yojson decimal" `Quick
            Vesta.test_field_of_yojson_decimal
        ; test_case "of_yojson invalid type" `Quick
            Vesta.test_field_of_yojson_invalid_type
        ; test_case "of_yojson zero decimal" `Quick
            Vesta.test_field_of_yojson_zero_decimal
        ; test_case "of_yojson one decimal" `Quick
            Vesta.test_field_of_yojson_one_decimal
        ; test_case "of_yojson 42 decimal" `Quick
            Vesta.test_field_of_yojson_42_decimal
        ; test_case "of_yojson modulus decimal" `Quick
            Vesta.test_field_of_yojson_modulus_decimal
        ] )
    ]
