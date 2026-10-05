(** Testing
    -------
    Component:  Signature_lib
    Invocation: dune exec \
                  src/lib/crypto/signature_lib/test/test_encoding_regression.exe
    Subject:    Regression tests for base58 encoding of cryptographic types.
 *)

open Signature_lib

(* Private_key from scalar 1 *)
let test_private_key_scalar_one_encoding () =
  let expected = "EKDheFCGxfVGKBunTkfkWv3WqiH7JXiYaTu3kv9pb389GBqPpUFr" in
  let t = Private_key.of_string_exn "1" in
  let got = Private_key.to_base58_check t in
  Alcotest.(check string)
    "Private_key(scalar=1) encoding is stable" expected got

(* Private_key from scalar 2 *)
let test_private_key_scalar_two_encoding () =
  let expected = "EKDi5nj98e6UhforSnEWPDFbWQMtkkKpdP6J3hyS61mDo64EJWSK" in
  let t = Private_key.of_string_exn "2" in
  let got = Private_key.to_base58_check t in
  Alcotest.(check string)
    "Private_key(scalar=2) encoding is stable" expected got

(* Public_key.Compressed derived from Private_key(scalar=1) *)
let test_public_key_compressed_from_scalar_one () =
  let expected = "B62qiVGZQdBJJrxnzhvqp7LKe6jDiFcpU3cF5xHoZof5Pz9qiL85KLx" in
  let sk = Private_key.of_string_exn "1" in
  let pk = Public_key.of_private_key_exn sk in
  let got = Public_key.Compressed.to_base58_check (Public_key.compress pk) in
  Alcotest.(check string)
    "Public_key.Compressed(sk=1) encoding is stable" expected got

(* Public_key.Compressed derived from Private_key(scalar=2) *)
let test_public_key_compressed_from_scalar_two () =
  let expected = "B62qs2xPJgNhvBw7ubgppB4YSDf1dYyvLYD1ghCrhnkXabLSVAainWx" in
  let sk = Private_key.of_string_exn "2" in
  let pk = Public_key.of_private_key_exn sk in
  let got = Public_key.Compressed.to_base58_check (Public_key.compress pk) in
  Alcotest.(check string)
    "Public_key.Compressed(sk=2) encoding is stable" expected got

let () =
  let open Alcotest in
  run "Base58 encoding regression"
    [ ( "base58 encoding regression"
      , [ test_case "Private_key scalar=1 encoding" `Quick
            test_private_key_scalar_one_encoding
        ; test_case "Private_key scalar=2 encoding" `Quick
            test_private_key_scalar_two_encoding
        ; test_case "Public_key.Compressed from scalar=1" `Quick
            test_public_key_compressed_from_scalar_one
        ; test_case "Public_key.Compressed from scalar=2" `Quick
            test_public_key_compressed_from_scalar_two
        ] )
    ]
