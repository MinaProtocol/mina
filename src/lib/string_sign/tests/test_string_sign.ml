open Core_kernel
open String_sign
open Mina_signature_kind

(* Create a keypair for testing *)
let keypair : Signature_lib.Keypair.t =
  let public_key =
    Signature_lib.Public_key.Compressed.of_base58_check_exn
      "B62qnNkiQn1t1Nhof2fyTtBTbHLbXcUDVX2BWpjGKKK3HsfP8LPhYgE"
    |> Signature_lib.Public_key.decompress_exn
  in
  let private_key =
    Signature_lib.Private_key.of_base58_check_exn
      "EKEyDHNLpR42jU8j9p13t6GA3wKBXdHszrV17G6jpfJbK8FZDfYo"
  in
  { public_key; private_key }

(* Test basic signing and verification with default network *)
let test_default_network () =
  let s =
    "Now is the time for all good men to come to the aid of their party"
  in
  let signature = sign keypair.private_key s in
  Alcotest.(check bool)
    "Sign and verify with default network" true
    (verify signature keypair.public_key s)

(* Test signing and verification with mainnet *)
let test_mainnet () =
  let s = "Rain and Spain don't rhyme with cheese" in
  let signature = sign ~signature_kind:Mainnet keypair.private_key s in
  Alcotest.(check bool)
    "Sign and verify with mainnet" true
    (verify ~signature_kind:Mainnet signature keypair.public_key s)

(* Test legacy mainnet signature verification *)
let test_legacy_mainnet () =
  let s = "Legacy signature for mainnet" in
  let signature =
    "\"7mX3ZLNHk9CKtMd7hFLXYwEBXyiosDug9BLWDND1KJEdyfMWX9oWHscxGMT3q4P9DdYiXsXFynsfoLhooy3XJ5dgduPSHw5u\""
    |> Yojson.Safe.from_string |> Mina_base.Signature.of_yojson
    |> Core_kernel.Result.ok |> Option.value_exn
  in
  Alcotest.(check bool)
    "Verify legacy mainnet signature" true
    (verify ~signature_kind:Mainnet signature keypair.public_key s)

(* Test signing and verification with testnet *)
let test_testnet () =
  let s = "In a galaxy far, far away" in
  let signature = sign ~signature_kind:Testnet keypair.private_key s in
  Alcotest.(check bool)
    "Sign and verify with testnet" true
    (verify ~signature_kind:Testnet signature keypair.public_key s)

(* Test legacy testnet signature verification *)
let test_legacy_testnet () =
  let s = "Legacy signature for testnet" in
  let signature =
    "\"7mXR8PX3MuDWa7vTWTy6NWE83nKkRQosU2NzcCohuP56qy5CmugUTEgVD14xRSPMD7DsdCsgD2Y6ehY6Dkh6hRTU28i6CF37\""
    |> Yojson.Safe.from_string |> Mina_base.Signature.of_yojson
    |> Core_kernel.Result.ok |> Option.value_exn
  in
  Alcotest.(check bool)
    "Verify legacy testnet signature" true
    (verify ~signature_kind:Testnet signature keypair.public_key s)

(* Test signing and verification with other networks *)
let test_other_network () =
  let s = "Sky is blue" in
  let signature =
    sign ~signature_kind:(Other_network "Foo") keypair.private_key s
  in
  Alcotest.(check bool)
    "Sign and verify with other network" true
    (verify ~signature_kind:(Other_network "Foo") signature keypair.public_key s)

(* Test that signatures from one network don't verify on others *)
let test_testnet_failures () =
  let s = "Some pills make you larger" in
  let signature = sign ~signature_kind:Testnet keypair.private_key s in

  (* Should verify with testnet *)
  Alcotest.(check bool)
    "Testnet signature verifies with testnet" true
    (verify ~signature_kind:Testnet signature keypair.public_key s) ;

  (* Should not verify with mainnet *)
  Alcotest.(check bool)
    "Testnet signature fails with mainnet" false
    (verify ~signature_kind:Mainnet signature keypair.public_key s) ;

  (* Should not verify with other network *)
  Alcotest.(check bool)
    "Testnet signature fails with other network" false
    (verify ~signature_kind:(Other_network "Foo") signature keypair.public_key s)

(* Test that mainnet signatures don't verify on other networks *)
let test_mainnet_failures () =
  let s = "Watson, come here, I need you" in
  let signature = sign ~signature_kind:Mainnet keypair.private_key s in

  (* Should verify with mainnet *)
  Alcotest.(check bool)
    "Mainnet signature verifies with mainnet" true
    (verify ~signature_kind:Mainnet signature keypair.public_key s) ;

  (* Should not verify with testnet *)
  Alcotest.(check bool)
    "Mainnet signature fails with testnet" false
    (verify ~signature_kind:Testnet signature keypair.public_key s) ;

  (* Should not verify with other network *)
  Alcotest.(check bool)
    "Mainnet signature fails with other network" false
    (verify ~signature_kind:(Other_network "Foo") signature keypair.public_key s)

(* Test that other network signatures don't verify on standard networks *)
let test_other_network_failures () =
  let s = "Roses are red" in
  let signature =
    sign ~signature_kind:(Other_network "Foo") keypair.private_key s
  in

  (* Should verify with the same other network *)
  Alcotest.(check bool)
    "Other network signature verifies with same network" true
    (verify ~signature_kind:(Other_network "Foo") signature keypair.public_key s) ;

  (* Should not verify with mainnet *)
  Alcotest.(check bool)
    "Other network signature fails with mainnet" false
    (verify ~signature_kind:Mainnet signature keypair.public_key s) ;

  (* Should not verify with testnet *)
  Alcotest.(check bool)
    "Other network signature fails with testnet" false
    (verify ~signature_kind:Testnet signature keypair.public_key s) ;

  (* Should not verify with different other network *)
  Alcotest.(check bool)
    "Other network signature fails with different other network" false
    (verify ~signature_kind:(Other_network "Bar") signature keypair.public_key s)

(* Define the test suite *)
let () =
  Alcotest.run "String_sign"
    [ ( "Basic signing and verification"
      , [ Alcotest.test_case "Default network" `Quick test_default_network
        ; Alcotest.test_case "Mainnet" `Quick test_mainnet
        ; Alcotest.test_case "Legacy mainnet" `Quick test_legacy_mainnet
        ; Alcotest.test_case "Testnet" `Quick test_testnet
        ; Alcotest.test_case "Legacy testnet" `Quick test_legacy_testnet
        ; Alcotest.test_case "Other network" `Quick test_other_network
        ] )
    ; ( "Cross-network verification failures"
      , [ Alcotest.test_case "Testnet failures" `Quick test_testnet_failures
        ; Alcotest.test_case "Mainnet failures" `Quick test_mainnet_failures
        ; Alcotest.test_case "Other network failures" `Quick
            test_other_network_failures
        ] )
    ]
