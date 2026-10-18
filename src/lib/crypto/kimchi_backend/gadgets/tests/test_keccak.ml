(** Testing
    -------
    Component: Kimchi gadgets - Keccak
    Subject: Testing Keccak hash function gadget
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/tests/test_keccak.exe *)

open Core_kernel
open Kimchi_gadgets
open Kimchi_gadgets_test_runner

let () =
  try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()

let test_keccak ?cs ?inp_endian ?out_endian ~nist ~len message expected =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        assert (String.length message % 2 = 0) ;
        let message =
          Array.to_list
          @@ exists
               (Typ.array ~length:(String.length message / 2) Field.typ)
               ~compute:(fun () ->
                 Array.of_list @@ Common.field_bytes_of_hex message )
        in
        let hashed =
          Array.of_list
          @@
          match nist with
          | true ->
              Keccak.nist_sha3 len message ?inp_endian ?out_endian
                ~byte_checks:true
          | false ->
              Keccak.pre_nist len message ?inp_endian ?out_endian
                ~byte_checks:true
        in

        let expected = Array.of_list @@ Common.field_bytes_of_hex expected in
        (* Check expected hash output *)
        as_prover (fun () ->
            for i = 0 to Array.length hashed - 1 do
              let byte_hash =
                Common.cvar_field_to_bignum_bigint_as_prover hashed.(i)
              in
              let byte_exp = Common.field_to_bignum_bigint expected.(i) in
              assert (Common.Bignum_bigint.(byte_hash = byte_exp))
            done ;
            () ) ;
        () )
  in
  Some cs

(* Positive tests *)
let cs_eth256_1byte =
  lazy
    (test_keccak ~nist:false ~len:256 "30"
       "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d" )

let cs_nist512_1byte =
  lazy
    (test_keccak ~nist:true ~len:512 "30"
       "2d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c" )

let cs135 =
  lazy
    (test_keccak ~nist:false ~len:256
       "391ccf9b5de23bb86ec6b2b142adb6e9ba6bee8519e7502fb8be8959fbd2672934cc3e13b7b45bf2b8a5cb48881790a7438b4a326a0c762e31280711e6b64fcc2e3e4e631e501d398861172ea98603618b8f23b91d0208b0b992dfe7fdb298b6465adafbd45e4f88ee9dc94e06bc4232be91587f78572c169d4de4d8b95b714ea62f1fbf3c67a4"
       "7d5655391ede9ca2945f32ad9696f464be8004389151ce444c89f688278f2e1d" )

let cs136 =
  lazy
    (test_keccak ~nist:false ~len:256
       "ff391ccf9b5de23bb86ec6b2b142adb6e9ba6bee8519e7502fb8be8959fbd2672934cc3e13b7b45bf2b8a5cb48881790a7438b4a326a0c762e31280711e6b64fcc2e3e4e631e501d398861172ea98603618b8f23b91d0208b0b992dfe7fdb298b6465adafbd45e4f88ee9dc94e06bc4232be91587f78572c169d4de4d8b95b714ea62f1fbf3c67a4"
       "37694fd4ba137be747eb25a85b259af5563e0a7a3010d42bd15963ac631b9d3f" )

let cs2 =
  lazy
    (test_keccak ~nist:false ~len:256 "a2c0"
       "9856642c690c036527b8274db1b6f58c0429a88d9f3b9298597645991f4f58f0" )

let test_eth256_1byte () = Lazy.force cs_eth256_1byte |> fun _ -> ()

let test_nist512_1byte () = Lazy.force cs_nist512_1byte |> fun _ -> ()

let test_nft_ownership () =
  let _cs =
    test_keccak ~nist:false ~len:256
      "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e"
      "63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36"
  in
  let _cs =
    test_keccak ~nist:false ~len:512
      "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e"
      "848cf716c2d64444d2049f215326b44c25a007127d2871c1b6004a9c3d102f637f31acb4501e59f3a0160066c8814816f4dc58a869f37f740e09b9a8757fa259"
  in
  ()

let test_two_blocks () =
  (* For Keccak *)
  let _cs =
    test_keccak ~nist:false ~len:256
      "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116df9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e42d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36"
      "560deb1d387f72dba729f0bd0231ad45998dda4b53951645322cf95c7b6261d9"
  in
  (* For NIST *)
  let _cs =
    test_keccak ~nist:true ~len:256
      "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116df9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e42d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36"
      "1784354c4bbfa5f54e5db23041089e65a807a7b970e3cfdba95e2fbe63b1c0e4"
  in
  ()

let test_135_bits_single_padded_byte () = Lazy.force cs135 |> fun _ -> ()

let test_136_bits_two_blocks () = Lazy.force cs136 |> fun _ -> ()

let test_135_bits_input_looks_padded () =
  test_keccak ?cs:(Lazy.force cs135) ~nist:false ~len:256
    "800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"
    "0edbbae289596c7da9fafe65931c5dce3439fb487b8286d6c1970e44eea39feb"
  |> fun _ -> ()

let test_136_bits_input_looks_padded () =
  test_keccak ?cs:(Lazy.force cs136) ~nist:false ~len:256
    "80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"
    "bbf1f49a2cc5678aa62196d0c3108d89425b81780e1e90bcec03b4fb5f834714"
  |> fun _ -> ()

let test_reuse_eth256_1byte () =
  test_keccak
    ?cs:(Lazy.force cs_eth256_1byte)
    ~nist:false ~len:256 "00"
    "bc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a"
  |> fun _ -> ()

let test_reuse () =
  let _cs =
    test_keccak ?cs:(Lazy.force cs2) ~nist:false ~len:256 "0a2c"
      "295b48ad49eff61c3abfd399c672232434d89a4ef3ca763b9dbebb60dbb32a8b"
  in
  ()

let test_endianness () =
  test_keccak ~nist:false ~len:256 ~inp_endian:Little ~out_endian:Little "2c0a"
    "8b2ab3db60bbbe9d3b76caf34e9ad834242372c699d3bf3a1cf6ef49ad485b29"
  |> fun _ -> ()

(* Negative tests *)
let test_bad_hex_input () =
  Alcotest.(check bool)
    "bad hex input should fail" true
    (Common.is_error (fun () ->
         test_keccak ~nist:false ~len:256 "a2c"
           "07f02d241eeba9c909a1be75e08d9e8ac3e61d9e24fa452a6785083e1527c467" )
    )

let test_bad_hex_input_2 () =
  Alcotest.(check bool)
    "bad hex input 2 should fail" true
    (Common.is_error (fun () ->
         test_keccak ~nist:true ~len:256 "0"
           "f39f4526920bb4c096e5722d64161ea0eb6dbd0b4ff0d812f31d56fb96142084" )
    )

let test_inconsistent_output_length_reuse () =
  Alcotest.(check bool)
    "inconsistent output length reuse should fail" true
    (Common.is_error (fun () ->
         test_keccak
           ?cs:(Lazy.force cs_nist512_1byte)
           ~nist:true ~len:256 "30"
           "f9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e4" )
    )

let test_inconsistent_padding_reuse () =
  Alcotest.(check bool)
    "inconsistent padding reuse should fail" true
    (Common.is_error (fun () ->
         test_keccak
           ?cs:(Lazy.force cs_eth256_1byte)
           ~nist:true ~len:256
           "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e"
           "63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36" )
    )

let test_inconsistent_endianness_reuse () =
  Alcotest.(check bool)
    "inconsistent endianness reuse should fail" true
    (Common.is_error (fun () ->
         test_keccak ?cs:(Lazy.force cs2) ~nist:false ~len:256
           ~inp_endian:Little ~out_endian:Little "2c0a"
           "8b2ab3db60bbbe9d3b76caf34e9ad834242372c699d3bf3a1cf6ef49ad485b29" )
    )

let () =
  let open Alcotest in
  run "Keccak gadget"
    [ ( "Positive tests"
      , [ test_case "eth256_1byte" `Quick test_eth256_1byte
        ; test_case "nist512_1byte" `Quick test_nist512_1byte
        ; test_case "NFT ownership message" `Quick test_nft_ownership
        ; test_case "Two blocks" `Quick test_two_blocks
        ; test_case "135 bits, single padded byte as 0x81" `Quick
            test_135_bits_single_padded_byte
        ; test_case "136 bits, 2 blocks and second is just padding" `Quick
            test_136_bits_two_blocks
        ; test_case "135 bits, input already looks padded" `Quick
            test_135_bits_input_looks_padded
        ; test_case "136 bits, input already looks padded" `Quick
            test_136_bits_input_looks_padded
        ; test_case "reuse eth256_1byte" `Quick test_reuse_eth256_1byte
        ; test_case "reuse constraint system" `Quick test_reuse
        ; test_case "endianness" `Quick test_endianness
        ] )
    ; ( "Negative tests"
      , [ test_case "bad hex input" `Quick test_bad_hex_input
        ; test_case "bad hex input 2" `Quick test_bad_hex_input_2
        ; test_case "inconsistent output length reuse" `Quick
            test_inconsistent_output_length_reuse
        ; test_case "inconsistent padding reuse" `Quick
            test_inconsistent_padding_reuse
        ; test_case "inconsistent endianness reuse" `Quick
            test_inconsistent_endianness_reuse
        ] )
    ]
