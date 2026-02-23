(* test_encodings.ml -- test Rosetta encodings *)

open Signature_lib
open Rosetta_coding
open Alcotest

let pk1 =
  Public_key.Compressed.of_base58_check_exn
    "B62qrcFstkpqXww1EkSGrqMCwCNho86kuqBd4FrAAUsPxNKdiPzAUsy"

let pk2 =
  Public_key.Compressed.of_base58_check_exn
    "B62qkfHpLpELqpMK6ZvUTJ5wRqKDRF3UHyJ4Kv3FU79Sgs4qpBnx5RR"

let expected_encoded_pk1 =
  "F34B505E1A05ECFB327D8D664FF6272DDF5CC1F69618BB6A4407E9533067E783"

let expected_encoded_pk2 =
  "41D49033D3A5784BCD2320C05CEEFF6B6FB266BD0277E8BBD35FDBA839FE77AD"

let test_pk1_encoding () =
  let encoded = Coding.of_public_key_compressed pk1 in
  check string "pk1 encoding matches" expected_encoded_pk1 encoded

let test_pk2_encoding () =
  let encoded = Coding.of_public_key_compressed pk2 in
  check string "pk2 encoding matches" expected_encoded_pk2 encoded

let () =
  run "Rosetta_encodings"
    [ ( "public_key_encodings"
      , [ test_case "pk1 encoding" `Quick test_pk1_encoding
        ; test_case "pk2 encoding" `Quick test_pk2_encoding
        ] )
    ]
