open Core_kernel

(* Helper functions for property testing *)
let check_property name predicate =
  (* Run property test multiple times with random inputs *)
  let rec check_n_times n =
    if n <= 0 then true
    else if predicate () then check_n_times (n - 1)
    else false
  in
  (* We run the property test 100 times *)
  Alcotest.(check bool) name true (check_n_times 100)

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
          "Decimal 1 should equal Field.one" true
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

  (* Property-based tests for field operations *)

  (* Addition properties *)
  let test_field_addition_commutativity () =
    check_property "Addition commutativity" (fun () ->
        let a = Field.random () in
        let b = Field.random () in
        Field.equal (Field.( + ) a b) (Field.( + ) b a) )

  let test_field_addition_associativity () =
    check_property "Addition associativity" (fun () ->
        let a = Field.random () in
        let b = Field.random () in
        let c = Field.random () in
        Field.equal
          (Field.( + ) (Field.( + ) a b) c)
          (Field.( + ) a (Field.( + ) b c)) )

  let test_field_addition_identity () =
    check_property "Addition identity" (fun () ->
        let a = Field.random () in
        Field.equal a (Field.( + ) a Field.zero) )

  let test_field_addition_inverse () =
    check_property "Addition inverse" (fun () ->
        let a = Field.random () in
        let neg_a = Field.negate a in
        Field.equal Field.zero (Field.( + ) a neg_a) )

  (* Multiplication properties *)
  let test_field_multiplication_commutativity () =
    check_property "Multiplication commutativity" (fun () ->
        let a = Field.random () in
        let b = Field.random () in
        Field.equal (Field.( * ) a b) (Field.( * ) b a) )

  let test_field_multiplication_associativity () =
    check_property "Multiplication associativity" (fun () ->
        let a = Field.random () in
        let b = Field.random () in
        let c = Field.random () in
        Field.equal
          (Field.( * ) (Field.( * ) a b) c)
          (Field.( * ) a (Field.( * ) b c)) )

  let test_field_multiplication_identity () =
    check_property "Multiplication identity" (fun () ->
        let a = Field.random () in
        Field.equal a (Field.( * ) a Field.one) )

  let test_field_multiplication_distributivity () =
    check_property "Multiplication distributivity" (fun () ->
        let a = Field.random () in
        let b = Field.random () in
        let c = Field.random () in
        Field.equal
          (Field.( * ) a (Field.( + ) b c))
          (Field.( + ) (Field.( * ) a b) (Field.( * ) a c)) )

  (* Division and Inverse properties *)
  let test_field_division_by_self () =
    check_property "Division by self" (fun () ->
        let a = Field.random () in
        if Field.equal a Field.zero then true
        else Field.equal Field.one (Field.( / ) a a) )

  let test_field_inverse_property () =
    check_property "Inverse property" (fun () ->
        let a = Field.random () in
        if Field.equal a Field.zero then true
        else
          let a_inv = Field.inv a in
          Field.equal Field.one (Field.( * ) a a_inv) )

  (* Field Subtraction properties *)
  let test_field_subtraction_property () =
    check_property "Subtraction property" (fun () ->
        let a = Field.random () in
        let b = Field.random () in
        Field.equal (Field.( - ) a b) (Field.( + ) a (Field.negate b)) )
end

module Pallas = Make (Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field)
module Vesta = Make (Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field)

let () =
  let open Alcotest in
  run "Field Tests"
    [ ( "Pallas Parsing"
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
    ; ( "Pallas Field Properties"
      , [ test_case "addition commutativity" `Quick
            Pallas.test_field_addition_commutativity
        ; test_case "addition associativity" `Quick
            Pallas.test_field_addition_associativity
        ; test_case "addition identity" `Quick
            Pallas.test_field_addition_identity
        ; test_case "addition inverse" `Quick Pallas.test_field_addition_inverse
        ; test_case "multiplication commutativity" `Quick
            Pallas.test_field_multiplication_commutativity
        ; test_case "multiplication associativity" `Quick
            Pallas.test_field_multiplication_associativity
        ; test_case "multiplication identity" `Quick
            Pallas.test_field_multiplication_identity
        ; test_case "multiplication distributivity" `Quick
            Pallas.test_field_multiplication_distributivity
        ; test_case "division by self" `Quick Pallas.test_field_division_by_self
        ; test_case "inverse property" `Quick Pallas.test_field_inverse_property
        ; test_case "subtraction property" `Quick
            Pallas.test_field_subtraction_property
        ] )
    ; ( "Vesta Parsing"
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
    ; ( "Vesta Field Properties"
      , [ test_case "addition commutativity" `Quick
            Vesta.test_field_addition_commutativity
        ; test_case "addition associativity" `Quick
            Vesta.test_field_addition_associativity
        ; test_case "addition identity" `Quick
            Vesta.test_field_addition_identity
        ; test_case "addition inverse" `Quick Vesta.test_field_addition_inverse
        ; test_case "multiplication commutativity" `Quick
            Vesta.test_field_multiplication_commutativity
        ; test_case "multiplication associativity" `Quick
            Vesta.test_field_multiplication_associativity
        ; test_case "multiplication identity" `Quick
            Vesta.test_field_multiplication_identity
        ; test_case "multiplication distributivity" `Quick
            Vesta.test_field_multiplication_distributivity
        ; test_case "division by self" `Quick Vesta.test_field_division_by_self
        ; test_case "inverse property" `Quick Vesta.test_field_inverse_property
        ; test_case "subtraction property" `Quick
            Vesta.test_field_subtraction_property
        ] )
    ]
