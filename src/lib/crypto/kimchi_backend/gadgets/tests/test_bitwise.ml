(** Testing
    -------
    Component: Kimchi gadgets - Bitwise
    Subject: Testing bitwise gadgets (rot, shift, xor, and, not)
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/tests/test_bitwise.exe *)

open Kimchi_gadgets
open Kimchi_gadgets_test_runner

let () =
  try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()

(** Test ROT64 gadget. Returns constraint system if satisfied. *)
let test_rot ?cs word length mode result =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        let word =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_string word)
        in
        let result =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_string result)
        in
        let output_rot = Bitwise.rot64 word length mode in
        Field.Assert.equal output_rot result )
  in
  cs

(** Test LSL and LSR gadgets. Returns constraint system if satisfied. *)
let test_shift ?cs word length mode result =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        let word =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_string word)
        in
        let result =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_string result)
        in
        let output_shift =
          match mode with
          | Bitwise.Left ->
              Bitwise.lsl64 word length
          | Bitwise.Right ->
              Bitwise.lsr64 word length
        in
        Field.Assert.equal output_shift result )
  in
  cs

(** Test XOR gadget. Returns constraint system if satisfied. *)
let test_xor ?cs left_input right_input output_xor length =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        let left_input =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex left_input)
        in
        let right_input =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex right_input)
        in
        let output_xor =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex output_xor)
        in
        let result = Bitwise.bxor left_input right_input length in
        Field.Assert.equal output_xor result )
  in
  cs

(** Test AND gadget. Returns constraint system if satisfied. *)
let test_and ?cs left_input right_input output_and length =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        let left_input =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex left_input)
        in
        let right_input =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex right_input)
        in
        let output_and =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex output_and)
        in
        let result = Bitwise.band left_input right_input length in
        Field.Assert.equal output_and result )
  in
  cs

(** Test NOT gadget. Returns constraint system if satisfied. *)
let test_not ?cs input output length =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        let input =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex input)
        in
        let output =
          exists Field.typ ~compute:(fun () -> Common.field_of_hex output)
        in
        let result_checked = Bitwise.bnot_checked input length in
        let result_unchecked = Bitwise.bnot_unchecked input length in
        Field.Assert.equal output result_checked ;
        Field.Assert.equal output result_unchecked )
  in
  cs

(* Rotation tests *)
let test_rot_zero_left () =
  let _cs = test_rot "0" 0 Bitwise.Left "0" in
  ()

let test_rot_zero_right () =
  let _cs = test_rot "0" 32 Bitwise.Right "0" in
  ()

let test_rot_one_left () =
  let _cs = test_rot "1" 1 Bitwise.Left "2" in
  ()

let test_rot_one_left_63 () =
  let _cs = test_rot "1" 63 Bitwise.Left "9223372036854775808" in
  ()

let test_rot_256_right () =
  let cs = test_rot "256" 4 Bitwise.Right "16" in
  let _cs =
    test_rot ~cs "6510615555426900570" 4 Bitwise.Right "11936128518282651045"
  in
  let _cs =
    test_rot "6510615555426900570" 4 Bitwise.Left "11936128518282651045"
  in
  ()

let test_rot_reuse () =
  let cs = test_rot "1234567890" 32 Bitwise.Right "5302428712241725440" in
  let _cs = test_rot ~cs "2651214356120862720" 32 Bitwise.Right "617283945" in
  let _cs = test_rot ~cs "1153202983878524928" 32 Bitwise.Right "268500993" in
  ()

let test_rot_negative () =
  Alcotest.(check bool)
    "rot 0 1 Left != 1" true
    (Common.is_error (fun () -> test_rot "0" 1 Bitwise.Left "1")) ;
  Alcotest.(check bool)
    "rot with 64 bits fails" true
    (Common.is_error (fun () -> test_rot "1" 64 Bitwise.Left "1")) ;
  let cs = test_rot "1234567890" 32 Bitwise.Right "5302428712241725440" in
  Alcotest.(check bool)
    "wrong cs reuse fails" true
    (Common.is_error (fun () -> test_rot ~cs "0" 0 Bitwise.Left "0"))

(* Shift tests *)
let test_shift_positive () =
  let cs1l = test_shift "0" 1 Bitwise.Left "0" in
  let cs1r = test_shift "0" 1 Bitwise.Right "0" in
  let _cs = test_shift ~cs:cs1l "1" 1 Bitwise.Left "2" in
  let _cs = test_shift ~cs:cs1r "1" 1 Bitwise.Right "0" in
  let _cs = test_shift "256" 4 Bitwise.Right "16" in
  let _cs = test_shift "256" 20 Bitwise.Right "0" in
  let _cs =
    test_shift "6510615555426900570" 16 Bitwise.Right "99344109427290"
  in
  let _cs =
    test_shift "18446744073709551615" 15 Bitwise.Left "18446744073709518848"
  in
  let _cs = test_shift "12523523412423524646" 32 Bitwise.Right "2915860016" in
  let _cs =
    test_shift "12523523412423524646" 32 Bitwise.Left "17134720101237391360"
  in
  ()

let test_shift_negative () =
  let cs_allones =
    test_shift "18446744073709551615" 15 Bitwise.Left "18446744073709518848"
  in
  Alcotest.(check bool)
    "shift 0 1 Left != 1" true
    (Common.is_error (fun () -> test_shift "0" 1 Bitwise.Left "1")) ;
  Alcotest.(check bool)
    "shift with 64 bits fails" true
    (Common.is_error (fun () -> test_shift "1" 64 Bitwise.Left "1")) ;
  Alcotest.(check bool)
    "wrong cs reuse fails" true
    (Common.is_error (fun () ->
         test_shift ~cs:cs_allones "0" 0 Bitwise.Left "0" ) )

(* XOR tests *)
let test_xor_positive () =
  let cs16 = test_xor "1" "0" "1" 16 in
  let _cs = test_xor ~cs:cs16 "0" "1" "1" 16 in
  let _cs = test_xor ~cs:cs16 "2" "1" "3" 16 in
  let _cs = test_xor ~cs:cs16 "a8ca" "ddd5" "751f" 16 in
  let _cs = test_xor ~cs:cs16 "0" "0" "0" 8 in
  let _cs = test_xor ~cs:cs16 "0" "0" "0" 1 in
  let _cs = test_xor ~cs:cs16 "1" "0" "1" 1 in
  let _cs = test_xor ~cs:cs16 "0" "0" "0" 4 in
  let _cs = test_xor ~cs:cs16 "1" "1" "0" 4 in
  let _cs = test_xor "bb5c6" "edded" "5682b" 20 in
  let cs64 =
    test_xor "5a5a5a5a5a5a5a5a" "a5a5a5a5a5a5a5a5" "ffffffffffffffff" 64
  in
  let _cs =
    test_xor ~cs:cs64 "f1f1f1f1f1f1f1f1" "0f0f0f0f0f0f0f0f" "fefefefefefefefe"
      64
  in
  let _cs =
    test_xor ~cs:cs64 "cad1f05900fcad2f" "deadbeef010301db" "147c4eb601ffacf4"
      64
  in
  ()

let test_xor_negative () =
  let cs32 = test_xor "bb5c6" "edded" "5682b" 20 in
  let cs16 = test_xor "1" "0" "1" 16 in
  Alcotest.(check bool)
    "wrong witness fails" true
    (Common.is_error (fun () -> test_xor ~cs:cs32 "ed1ed1" "ed1ed1" "010101" 20)) ;
  Alcotest.(check bool)
    "wrong cs fails" true
    (Common.is_error (fun () -> test_xor ~cs:cs32 "1" "1" "0" 16)) ;
  Alcotest.(check bool)
    "length 0 fails" true
    (Common.is_error (fun () -> test_xor ~cs:cs16 "1" "0" "1" 0)) ;
  Alcotest.(check bool)
    "wrong result fails" true
    (Common.is_error (fun () -> test_xor ~cs:cs16 "1" "0" "0" 1)) ;
  Alcotest.(check bool)
    "length 256 fails" true
    (Common.is_error (fun () -> test_xor "0" "0" "0" 256)) ;
  Alcotest.(check bool)
    "negative length fails" true
    (Common.is_error (fun () -> test_xor "0" "0" "0" (-4))) ;
  Alcotest.(check bool)
    "wrong xor result fails" true
    (Common.is_error (fun () -> test_xor ~cs:cs32 "bb5c6" "edded" "ed1ed1" 20))

(* AND tests *)
let test_and_positive () =
  let cs = test_and "0" "0" "0" 16 in
  let _cs = test_and ~cs "457" "8ae" "6" 16 in
  let _cs = test_and ~cs "a8ca" "ddd5" "88c0" 16 in
  let _cs = test_and "0" "0" "0" 8 in
  let cs = test_and "1" "1" "1" 1 in
  let _cs = test_and ~cs "1" "0" "0" 1 in
  let _cs = test_and ~cs "0" "1" "0" 1 in
  let _cs = test_and ~cs "0" "0" "0" 1 in
  let _cs = test_and "f" "f" "f" 4 in
  let _cs = test_and "bb5c6" "edded" "a95c4" 20 in
  let cs = test_and "5a5a5a5a5a5a5a5a" "a5a5a5a5a5a5a5a5" "0" 64 in
  let _cs =
    test_and ~cs "385e243cb60654fd" "010fde9342c0d700" "e041002005400" 64
  in
  ()

let test_and_negative () =
  let cs = test_and "385e243cb60654fd" "010fde9342c0d700" "e041002005400" 64 in
  Alcotest.(check bool)
    "wrong witness fails" true
    (Common.is_error (fun () -> test_and ~cs "1" "1" "0" 20)) ;
  Alcotest.(check bool)
    "wrong cs fails" true
    (Common.is_error (fun () -> test_and ~cs "1" "1" "1" 1)) ;
  Alcotest.(check bool)
    "wrong and result fails" true
    (Common.is_error (fun () -> test_and "1" "1" "0" 1)) ;
  Alcotest.(check bool)
    "length 7 with ff fails" true
    (Common.is_error (fun () -> test_and "ff" "ff" "ff" 7)) ;
  Alcotest.(check bool)
    "negative length fails" true
    (Common.is_error (fun () -> test_and "1" "1" "1" (-1)))

(* NOT tests *)
let test_not_positive () =
  let _cs = test_not "0" "1" 1 in
  let _cs = test_not "0" "f" 4 in
  let _cs = test_not "0" "ff" 8 in
  let _cs = test_not "0" "7ff" 11 in
  let cs16 = test_not "0" "ffff" 16 in
  let _cs = test_not ~cs:cs16 "a8ca" "5735" 16 in
  let _cs = test_not "bb5c6" "44a39" 20 in
  let cs64 = test_not "a5a5a5a5a5a5a5a5" "5a5a5a5a5a5a5a5a" 64 in
  let _cs = test_not ~cs:cs64 "5a5a5a5a5a5a5a5a" "a5a5a5a5a5a5a5a5" 64 in
  let _cs = test_not ~cs:cs64 "7b3f28d7496d75f0" "84c0d728b6928a0f" 64 in
  let _cs = test_not ~cs:cs64 "ffffffffffffffff" "0" 64 in
  let _cs = test_not ~cs:cs64 "00000fffffffffff" "fffff00000000000" 64 in
  let _cs = test_not ~cs:cs64 "fffffffffffff000" "fff" 64 in
  let _cs = test_not ~cs:cs64 "0" "ffffffffffffffff" 64 in
  let _cs =
    test_not "3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
      "0" 254
  in
  ()

let test_not_negative () =
  let cs64 = test_not "a5a5a5a5a5a5a5a5" "5a5a5a5a5a5a5a5a" 64 in
  let cs16 = test_not "0" "ffff" 16 in
  Alcotest.(check bool)
    "wrong witness fails" true
    (Common.is_error (fun () -> test_not ~cs:cs64 "0" "ff" 64)) ;
  Alcotest.(check bool)
    "wrong cs fails" true
    (Common.is_error (fun () -> test_not ~cs:cs16 "1" "0" 1)) ;
  Alcotest.(check bool)
    "wrong not result fails" true
    (Common.is_error (fun () -> test_not "0" "0" 1)) ;
  Alcotest.(check bool)
    "length 4 with ff fails" true
    (Common.is_error (fun () -> test_not "ff" "0" 4)) ;
  Alcotest.(check bool)
    "length 255 fails" true
    (Common.is_error (fun () ->
         test_not
           "7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
           "0" 255 ) )

let () =
  let open Alcotest in
  run "Bitwise gadgets"
    [ ( "Rotation gadget"
      , [ test_case "rot zero left" `Quick test_rot_zero_left
        ; test_case "rot zero right" `Quick test_rot_zero_right
        ; test_case "rot one left" `Quick test_rot_one_left
        ; test_case "rot one left 63" `Quick test_rot_one_left_63
        ; test_case "rot 256 right" `Quick test_rot_256_right
        ; test_case "rot reuse constraint system" `Quick test_rot_reuse
        ; test_case "rot negative tests" `Quick test_rot_negative
        ] )
    ; ( "Shift gadget"
      , [ test_case "shift positive tests" `Quick test_shift_positive
        ; test_case "shift negative tests" `Quick test_shift_negative
        ] )
    ; ( "XOR gadget"
      , [ test_case "xor positive tests" `Quick test_xor_positive
        ; test_case "xor negative tests" `Quick test_xor_negative
        ] )
    ; ( "AND gadget"
      , [ test_case "and positive tests" `Quick test_and_positive
        ; test_case "and negative tests" `Quick test_and_negative
        ] )
    ; ( "NOT gadget"
      , [ test_case "not positive tests" `Quick test_not_positive
        ; test_case "not negative tests" `Quick test_not_negative
        ] )
    ]
