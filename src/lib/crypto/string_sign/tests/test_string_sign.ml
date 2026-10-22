open Core_kernel
open String_sign
open Mina_signature_kind
open Base_quickcheck

let seed =
  let () = Random.self_init () in
  let seed_phrase = List.init 32 ~f:(fun _ -> Random.int 256) in
  let seed_str =
    List.map seed_phrase ~f:Char.of_int_exn |> String.of_char_list
  in
  `Deterministic seed_str

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
  let signature_kind = Mina_signature_kind.Testnet in
  let signature = sign ~signature_kind keypair.private_key s in
  Alcotest.(check bool)
    "Sign and verify with default network" true
    (verify ~signature_kind signature keypair.public_key s)

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

let test_secret_key_between_scalar_field_and_base_field () =
  (* There are 86663725065984043395317760 values between the two moduli.
     - Base:
       28948022309329048855892746252171976963363056481941560715954676764349967630337
     - Scalar:
       28948022309329048855892746252171976963363056481941647379679742748393362948097
     We use the predefined value of the scalar field of Vesta for the base
     field of Pallas, the size not being available in the exported interface for
     Tick.Inner_curve.Base_field *)
  let base_modulus = Snark_params.Tock.Inner_curve.Scalar.size in

  (* Generator for random offset within the range between base and scalar moduli *)
  let offset_gen = Generator.int64_inclusive 1L Int64.max_value in

  (* Combined generator for both signature kind and offset *)
  let combined_gen =
    let open Quickcheck.Generator.Let_syntax in
    let%bind signature_kind = Mina_signature_kind.signature_kind_gen seed in
    let%map offset = offset_gen in
    (signature_kind, offset)
  in

  Quickcheck.test ~seed ~trials:10 combined_gen
    ~f:(fun (signature_kind, random_offset) ->
      let sk_bignum =
        Bignum_bigint.(base_modulus + of_string (Int64.to_string random_offset))
      in
      let sk_str = Bignum_bigint.to_string sk_bignum in

      let secret_key = Signature_lib.Private_key.of_string_exn sk_str in
      let keypair = Signature_lib.Keypair.of_private_key_exn secret_key in

      let s = "Rain and Spain don't rhyme with cheese" in
      let signature = sign ~signature_kind keypair.private_key s in
      Alcotest.(check bool)
        "Sign and verify with secret key in scalar field" true
        (verify ~signature_kind signature keypair.public_key s) )

let test_regression_signature () =
  let inputs =
    [ ( Signature_lib.Private_key.of_string_exn
          "28948022309329048855892746252171976963363056481941560715954676764349967630337"
      , Mina_signature_kind.Mainnet )
    ; ( Signature_lib.Private_key.of_string_exn
          "28948022309329048855892746252171976963363056481941560715954676764349967630337"
      , Mina_signature_kind.Testnet )
    ]
  in
  let exp_output =
    [ ( "10098659636052751402960513659673534058318534694837361110423199873688986365908"
      , "7844530585816769124362208605281765856859093320029640751494040544682079710450"
      )
    ; ( "19528641019288828403170135634909672400537532147682562327700497341129840775560"
      , "24640829174932073706335857230587954505385529622139330517748682166416541732513"
      )
    ]
  in
  let l = List.zip_exn inputs exp_output in
  List.iter l ~f:(fun ((sk, signature_kind), (exp_r_str, exp_s_str)) ->
      (* Create a keypair from the secret key *)
      let keypair = Signature_lib.Keypair.of_private_key_exn sk in
      let msg = "Bitcoin: A Peer-to-Peer Electronic Cash System" in
      let r, s = sign ~signature_kind keypair.private_key msg in
      Alcotest.(check bool)
        "r values match expected output" true
        (String.equal
           (Snark_params.Tock.Inner_curve.Scalar.to_string r)
           exp_r_str ) ;
      Alcotest.(check bool)
        "s values match expected output" true
        (String.equal
           (Snark_params.Tick.Inner_curve.Scalar.to_string s)
           exp_s_str ) )

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
    ; ( "Corner cases"
      , [ Alcotest.test_case "Secret key between scalar and base field" `Quick
            test_secret_key_between_scalar_field_and_base_field
        ] )
    ; ( " Regression signature test"
      , [ Alcotest.test_case "Signature regression" `Quick
            test_regression_signature
        ] )
    ]
