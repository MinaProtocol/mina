open Core_kernel
open Signature_lib
open Alcotest
open Base_quickcheck

let seed =
  let () = Random.self_init () in
  let seed_phrase = List.init 32 ~f:(fun _ -> Random.int 256) in
  let seed_str =
    List.map seed_phrase ~f:Char.of_int_exn |> String.of_char_list
  in
  `Deterministic seed_str

(* Test vectors for Chunked derive_for_mainnet and derive_for_testnet functions *)

(* Helper to create test private keys *)
let create_test_private_key s = Snark_params.Tick.Inner_curve.Scalar.of_string s

(* Helper to create test public key from private key *)
let create_public_key_from_private pk =
  Snark_params.Tick.Inner_curve.(scale one pk)

(* Helper to create empty random oracle input *)
let empty_chunked_input = Random_oracle_input.Chunked.field_elements [||]

(* Helper to create test message with field elements *)
let chunked_input_with_fields fields =
  Random_oracle_input.Chunked.field_elements
    (Array.of_list (List.map fields ~f:Snark_params.Tick.Field.of_string))

(* Standard test private key *)
let test_privkey1 = create_test_private_key "12345"

(* Another test private key *)
let test_privkey2 = create_test_private_key "98765"

(* Corner case: private key = scalar field modulus - 1 *)
let scalar_modulus_str =
  Bigint.to_string Snark_params.Tick.Inner_curve.Scalar.size

let scalar_modulus_minus_1 =
  Bignum_bigint.(scalar_modulus_str |> of_string |> pred |> to_string)

let corner_privkey_scalar_max = create_test_private_key scalar_modulus_minus_1

(* Corner case: private key using base field size - 1 *)
let base_field_modulus_str = Bigint.to_string Snark_params.Tick.Field.size

let base_field_modulus_minus_1 =
  Bignum_bigint.(base_field_modulus_str |> of_string |> pred |> to_string)

let corner_privkey_base_max = create_test_private_key base_field_modulus_minus_1

(* Test vectors for derive_for_mainnet *)

let test_derive_for_mainnet_empty_input () =
  let private_key = test_privkey1 in
  let public_key = create_public_key_from_private private_key in
  let derived =
    Schnorr.Message.Chunked.derive_for_mainnet empty_chunked_input ~private_key
      ~public_key
  in
  let expected =
    "3593510266845031606199417412802645135386671476060311361956367865683456961999"
  in
  check bool "derive_for_mainnet with empty input" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_mainnet_single_field () =
  let private_key = test_privkey2 in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "42" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_mainnet message ~private_key ~public_key
  in
  let expected =
    "5619064452189285627845965652490438781527755092950194256949446363932844311998"
  in
  check bool "derive_for_mainnet with single field element" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_mainnet_multiple_fields () =
  let private_key = test_privkey1 in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "1"; "2"; "3"; "4"; "5" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_mainnet message ~private_key ~public_key
  in
  let expected =
    "1124847115894633099179585118316876374220267648742248518331982305418971276757"
  in
  check bool "derive_for_mainnet with multiple field elements" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_mainnet_corner_case_scalar_max () =
  let private_key = corner_privkey_scalar_max in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "1000" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_mainnet message ~private_key ~public_key
  in
  let expected =
    "18415544288045082845294221318898079394929596923113905209738653257828934473252"
  in
  check bool "derive_for_mainnet with scalar modulus - 1 private key" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_mainnet_corner_case_base_max () =
  let private_key = corner_privkey_base_max in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "2000" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_mainnet message ~private_key ~public_key
  in
  let expected =
    "2974746907860182244799713952694417727612392959419953022200172828905564499495"
  in
  check bool "derive_for_mainnet with base field modulus - 1 private key" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

(* Test vectors for derive_for_testnet *)

let test_derive_for_testnet_empty_input () =
  let private_key = test_privkey1 in
  let public_key = create_public_key_from_private private_key in
  let derived =
    Schnorr.Message.Chunked.derive_for_testnet empty_chunked_input ~private_key
      ~public_key
  in
  let expected =
    "12050222805662643658060125978245066462988462138104028068015115694880454896700"
  in
  check bool "derive_for_testnet with empty input" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_testnet_single_field () =
  let private_key = test_privkey2 in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "42" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_testnet message ~private_key ~public_key
  in
  let expected =
    "27060089521084789061404877029819834217748792359356057334897351652268596433002"
  in
  check bool "derive_for_testnet with single field element" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_testnet_multiple_fields () =
  let private_key = test_privkey1 in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "1"; "2"; "3"; "4"; "5" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_testnet message ~private_key ~public_key
  in
  let expected =
    "18369258700166284571888737119702768566919086299535085697762400913559910179943"
  in
  check bool "derive_for_testnet with multiple field elements" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_testnet_corner_case_scalar_max () =
  let private_key = corner_privkey_scalar_max in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "1000" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_testnet message ~private_key ~public_key
  in
  let expected =
    "5775053650311195327575287700717960521187241946253469084251372495989542569423"
  in
  check bool "derive_for_testnet with scalar modulus - 1 private key" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_for_testnet_corner_case_base_max () =
  let private_key = corner_privkey_base_max in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "2000" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_testnet message ~private_key ~public_key
  in
  let expected =
    "18123950300512439416645058305812283408574438726914147563703695313801386267673"
  in
  check bool "derive_for_testnet with base field modulus - 1 private key" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

(* Test zero input - edge case *)

let test_derive_zero_input_mainnet () =
  let private_key = create_test_private_key "1" in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "0" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_mainnet message ~private_key ~public_key
  in
  let expected =
    "21668637711151334752874460313903444394531543832240118737647275916622371175833"
  in
  check bool "derive_for_mainnet with zero input" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

let test_derive_zero_input_testnet () =
  let private_key = create_test_private_key "1" in
  let public_key = create_public_key_from_private private_key in
  let message = chunked_input_with_fields [ "0" ] in
  let derived =
    Schnorr.Message.Chunked.derive_for_testnet message ~private_key ~public_key
  in
  let expected =
    "16461875322681100271036306734872833179150526484956591198733363727134724357203"
  in
  check bool "derive_for_testnet with zero input" true
    (Snark_params.Tock.Field.equal derived
       (Snark_params.Tock.Field.of_string expected) )

(* QuickCheck property-based tests *)

let test_derive_consistency_mainnet_vs_testnet () =
  let gen = Generator.int_inclusive 1 1000000 in
  Quickcheck.test ~seed ~trials:10 gen ~f:(fun value ->
      let private_key = create_test_private_key (Int.to_string value) in
      let public_key = create_public_key_from_private private_key in
      let field_value =
        Snark_params.Tick.Field.of_string (Int.to_string (value + 42))
      in
      let message =
        Random_oracle_input.Chunked.field_elements [| field_value |]
      in
      let mainnet_result =
        Schnorr.Message.Chunked.derive_for_mainnet message ~private_key
          ~public_key
      in
      let testnet_result =
        Schnorr.Message.Chunked.derive_for_testnet message ~private_key
          ~public_key
      in
      check bool "mainnet and testnet should always produce different results"
        false
        (Snark_params.Tock.Field.equal mainnet_result testnet_result) )

let test_derive_deterministic_mainnet () =
  let gen = Generator.int_inclusive 1 1000000 in
  Quickcheck.test ~seed ~trials:10 gen ~f:(fun value ->
      let private_key = create_test_private_key (Int.to_string value) in
      let public_key = create_public_key_from_private private_key in
      let field_value =
        Snark_params.Tick.Field.of_string (Int.to_string (value + 42))
      in
      let message =
        Random_oracle_input.Chunked.field_elements [| field_value |]
      in
      let result1 =
        Schnorr.Message.Chunked.derive_for_mainnet message ~private_key
          ~public_key
      in
      let result2 =
        Schnorr.Message.Chunked.derive_for_mainnet message ~private_key
          ~public_key
      in
      check bool "derive_for_mainnet should be deterministic" true
        (Snark_params.Tock.Field.equal result1 result2) )

let test_derive_deterministic_testnet () =
  let gen = Generator.int_inclusive 1 1000000 in
  Quickcheck.test ~seed ~trials:10 gen ~f:(fun value ->
      let private_key = create_test_private_key (Int.to_string value) in
      let public_key = create_public_key_from_private private_key in
      let field_value =
        Snark_params.Tick.Field.of_string (Int.to_string (value + 42))
      in
      let message =
        Random_oracle_input.Chunked.field_elements [| field_value |]
      in
      let result1 =
        Schnorr.Message.Chunked.derive_for_testnet message ~private_key
          ~public_key
      in
      let result2 =
        Schnorr.Message.Chunked.derive_for_testnet message ~private_key
          ~public_key
      in
      check bool "derive_for_testnet should be deterministic" true
        (Snark_params.Tock.Field.equal result1 result2) )

let test_derive_different_private_keys () =
  let gen = Generator.int_inclusive 1 500000 in
  Quickcheck.test ~seed ~trials:10 gen ~f:(fun value ->
      let private_key1 = create_test_private_key (Int.to_string value) in
      let private_key2 =
        create_test_private_key (Int.to_string ((value * 2) + 1))
      in
      let field_value =
        Snark_params.Tick.Field.of_string (Int.to_string (value + 100))
      in
      let message =
        Random_oracle_input.Chunked.field_elements [| field_value |]
      in
      let public_key1 = create_public_key_from_private private_key1 in
      let public_key2 = create_public_key_from_private private_key2 in
      let result1 =
        Schnorr.Message.Chunked.derive_for_mainnet message
          ~private_key:private_key1 ~public_key:public_key1
      in
      let result2 =
        Schnorr.Message.Chunked.derive_for_mainnet message
          ~private_key:private_key2 ~public_key:public_key2
      in
      check bool "different private keys should produce different results" false
        (Snark_params.Tock.Field.equal result1 result2) )

let test_derive_different_messages () =
  let gen = Generator.int_inclusive 1 1000000 in
  Quickcheck.test ~seed ~trials:10 gen ~f:(fun value ->
      let private_key = create_test_private_key (Int.to_string value) in
      let public_key = create_public_key_from_private private_key in
      let field1 = Snark_params.Tick.Field.of_string (Int.to_string value) in
      let field2 =
        Snark_params.Tick.Field.of_string (Int.to_string (value + 1000))
      in
      let message1 = Random_oracle_input.Chunked.field_elements [| field1 |] in
      let message2 = Random_oracle_input.Chunked.field_elements [| field2 |] in
      let result1 =
        Schnorr.Message.Chunked.derive_for_mainnet message1 ~private_key
          ~public_key
      in
      let result2 =
        Schnorr.Message.Chunked.derive_for_mainnet message2 ~private_key
          ~public_key
      in
      check bool "different messages should produce different results" false
        (Snark_params.Tock.Field.equal result1 result2) )

let test_derive_multiple_field_elements () =
  let gen = Generator.int_inclusive 1 1000000 in
  Quickcheck.test ~seed ~trials:10 gen ~f:(fun value ->
      let private_key = create_test_private_key (Int.to_string value) in
      let public_key = create_public_key_from_private private_key in
      let field_list =
        List.init 3 ~f:(fun i ->
            Snark_params.Tick.Field.of_string (Int.to_string (value + i)) )
      in
      let message =
        Random_oracle_input.Chunked.field_elements (Array.of_list field_list)
      in
      let mainnet_result =
        Schnorr.Message.Chunked.derive_for_mainnet message ~private_key
          ~public_key
      in
      let testnet_result =
        Schnorr.Message.Chunked.derive_for_testnet message ~private_key
          ~public_key
      in
      check bool "mainnet and testnet should produce different results" false
        (Snark_params.Tock.Field.equal mainnet_result testnet_result) )

let () =
  run "Chunked derive_for_mainnet and derive_for_testnet test vectors"
    [ ( "derive_for_mainnet tests"
      , [ test_case "empty input" `Quick test_derive_for_mainnet_empty_input
        ; test_case "single field element" `Quick
            test_derive_for_mainnet_single_field
        ; test_case "multiple field elements" `Quick
            test_derive_for_mainnet_multiple_fields
        ; test_case "corner case: scalar modulus - 1" `Quick
            test_derive_for_mainnet_corner_case_scalar_max
        ; test_case "corner case: base field modulus - 1" `Quick
            test_derive_for_mainnet_corner_case_base_max
        ; test_case "zero input" `Quick test_derive_zero_input_mainnet
        ] )
    ; ( "derive_for_testnet tests"
      , [ test_case "empty input" `Quick test_derive_for_testnet_empty_input
        ; test_case "single field element" `Quick
            test_derive_for_testnet_single_field
        ; test_case "multiple field elements" `Quick
            test_derive_for_testnet_multiple_fields
        ; test_case "corner case: scalar modulus - 1" `Quick
            test_derive_for_testnet_corner_case_scalar_max
        ; test_case "corner case: base field modulus - 1" `Quick
            test_derive_for_testnet_corner_case_base_max
        ; test_case "zero input" `Quick test_derive_zero_input_testnet
        ] )
    ; ( "PBT with QuickCheck"
      , [ test_case "mainnet vs testnet consistency (detailed)" `Quick
            test_derive_consistency_mainnet_vs_testnet
        ; test_case "mainnet deterministic" `Quick
            test_derive_deterministic_mainnet
        ; test_case "testnet deterministic" `Quick
            test_derive_deterministic_testnet
        ; test_case "different private keys (detailed)" `Quick
            test_derive_different_private_keys
        ; test_case "different messages (detailed)" `Quick
            test_derive_different_messages
        ; test_case "multiple field elements" `Quick
            test_derive_multiple_field_elements
        ] )
    ]
