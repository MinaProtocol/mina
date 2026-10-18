(** Testing
    -------
    Component: Kimchi gadgets - Common
    Subject: Testing common helper functions
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/tests/test_common.exe *)

open Kimchi_gadgets
open Kimchi_gadgets_test_runner

let () =
  try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()

let test_field_bits_le_to_field () =
  let _cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof (fun () ->
        let open Runner.Impl in
        let of_bits = Common.as_prover_cvar_field_bits_le_to_cvar_field in
        let of_base10 = Common.as_prover_cvar_field_of_base10 in

        (* Test value *)
        let field_element =
          of_base10
            "25138500177533925254565157548260087092526215225485178888176592492127995051965"
        in

        (* Test extracting all bits as field element *)
        Field.Assert.equal (of_bits field_element 0 (-1)) field_element ;

        (* Test extracting 1st bit as field element *)
        Field.Assert.equal (of_bits field_element 0 1) (of_base10 "1") ;

        (* Test extracting last bit as field element *)
        Field.Assert.equal (of_bits field_element 254 255) (of_base10 "0") ;

        (* Test extracting first 12 bits as field element *)
        Field.Assert.equal (of_bits field_element 0 12) (of_base10 "4029") ;

        (* Test extracting third 16 bits as field element *)
        Field.Assert.equal (of_bits field_element 32 48) (of_base10 "15384") ;

        (* Test extracting 1st 4 bits as field element *)
        Field.Assert.equal (of_bits field_element 0 4) (of_base10 "13") ;

        (* Test extracting 5th 4 bits as field element *)
        Field.Assert.equal (of_bits field_element 20 24) (of_base10 "1") ;

        (* Test extracting first 88 bits as field element *)
        Field.Assert.equal
          (of_bits field_element 0 88)
          (of_base10 "155123280218940970272309181") ;

        (* Test extracting second 88 bits as field element *)
        Field.Assert.equal
          (of_bits field_element 88 176)
          (of_base10 "293068737190883252403551981") ;

        (* Test extracting last crumb as field element *)
        Field.Assert.equal (of_bits field_element 254 255) (of_base10 "0") ;

        (* Test extracting 2nd to last crumb as field element *)
        Field.Assert.equal (of_bits field_element 252 254) (of_base10 "3") ;

        (* Test extracting 3rd to last crumb as field element *)
        Field.Assert.equal (of_bits field_element 250 252) (of_base10 "1") ;

        (* Assert little-endian order *)
        Field.Assert.equal
          (of_bits (of_base10 "18446744073709551616" (* 2^64 *)) 64 65)
          (of_base10 "1") ;

        (* Test invalid range is denied *)
        assert (Common.is_error (fun () -> of_bits field_element 2 2)) ;
        assert (Common.is_error (fun () -> of_bits field_element 2 1)) ;

        (* Padding *)
        Boolean.Assert.is_true (Field.equal field_element field_element) )
  in
  ()

let () =
  let open Alcotest in
  run "Common helpers"
    [ ( "field_bits_le_to_field"
      , [ test_case "extract bits from field element" `Quick
            test_field_bits_le_to_field
        ] )
    ]
