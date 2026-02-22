(** Testing
    -------
    Component: Kimchi gadgets - Generic
    Subject: Testing generic gate gadgets (add, sub, mul)
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/tests/test_generic.exe *)

open Kimchi_gadgets
open Kimchi_gadgets_test_runner

let () =
  try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()

(** Test generic add gate gadget.
    Inputs: left_input + right_input = sum.
    Returns constraint system if satisfied, raises otherwise. *)
let test_generic_add ?cs left_input right_input sum =
  (* Generate and verify proof *)
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        (* Set up snarky variables for inputs and outputs *)
        let left_input =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int left_input)
        in
        let right_input =
          exists Field.typ ~compute:(fun () ->
              Field.Constant.of_int right_input )
        in
        let sum =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int sum)
        in
        (* Use the generic add gate gadget *)
        let result = Generic.add left_input right_input in
        Field.Assert.equal sum result ;
        (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
        Boolean.Assert.is_true (Field.equal sum sum) )
  in
  cs

(** Test generic sub gate gadget.
    Inputs: left_input - right_input = difference.
    Returns constraint system if satisfied, raises otherwise. *)
let test_generic_sub ?cs left_input right_input difference =
  (* Generate and verify proof *)
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        (* Set up snarky variables for inputs and outputs *)
        let left_input =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int left_input)
        in
        let right_input =
          exists Field.typ ~compute:(fun () ->
              Field.Constant.of_int right_input )
        in
        let difference =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int difference)
        in
        (* Use the generic sub gate gadget *)
        let result = Generic.sub left_input right_input in
        Field.Assert.equal difference result ;
        (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
        Boolean.Assert.is_true (Field.equal difference difference) )
  in
  cs

(** Test generic multiplication gate gadget.
    Inputs: left_input * right_input = prod.
    Returns constraint system if satisfied, raises otherwise. *)
let test_generic_mul ?cs left_input right_input prod =
  (* Generate and verify proof *)
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        (* Set up snarky variables for inputs and outputs *)
        let left_input =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int left_input)
        in
        let right_input =
          exists Field.typ ~compute:(fun () ->
              Field.Constant.of_int right_input )
        in
        let prod =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int prod)
        in
        (* Use the generic mul gate gadget *)
        let result = Generic.mul left_input right_input in
        Field.Assert.equal prod result ;
        (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
        Boolean.Assert.is_true (Field.equal prod prod) )
  in
  cs

(* TEST generic add gadget *)
let test_add_zero_plus_zero () =
  let _cs = test_generic_add 0 0 0 in
  ()

let test_add_one_plus_two () =
  let cs = test_generic_add 0 0 0 in
  let _cs = test_generic_add ~cs 1 2 3 in
  ()

let test_add_negative_wrong_result () =
  let cs = test_generic_add 0 0 0 in
  Alcotest.(check bool)
    "1 + 0 = 0 should fail" true
    (Common.is_error (fun () -> test_generic_add ~cs 1 0 0))

let test_add_negative_wrong_sum () =
  let cs = test_generic_add 0 0 0 in
  Alcotest.(check bool)
    "2 + 4 = 7 should fail" true
    (Common.is_error (fun () -> test_generic_add ~cs 2 4 7))

(* TEST generic sub gadget *)
let test_sub_zero_minus_zero () =
  let _cs = test_generic_sub 0 0 0 in
  ()

let test_sub_two_minus_one () =
  let cs = test_generic_sub 0 0 0 in
  let _cs = test_generic_sub ~cs 2 1 1 in
  ()

let test_sub_negative_wrong_result () =
  let cs = test_generic_sub 0 0 0 in
  Alcotest.(check bool)
    "4 - 2 = 1 should fail" true
    (Common.is_error (fun () -> test_generic_sub ~cs 4 2 1))

let test_sub_negative_wrong_difference () =
  let cs = test_generic_sub 0 0 0 in
  Alcotest.(check bool)
    "13 - 4 = 10 should fail" true
    (Common.is_error (fun () -> test_generic_sub ~cs 13 4 10))

(* TEST generic mul gadget *)
let test_mul_zero_times_zero () =
  let _cs = test_generic_mul 0 0 0 in
  ()

let test_mul_one_times_two () =
  let cs = test_generic_mul 0 0 0 in
  let _cs = test_generic_mul ~cs 1 2 2 in
  ()

let test_mul_negative_wrong_result () =
  let cs = test_generic_mul 0 0 0 in
  Alcotest.(check bool)
    "1 * 0 = 1 should fail" true
    (Common.is_error (fun () -> test_generic_mul ~cs 1 0 1))

let test_mul_negative_wrong_product () =
  let cs = test_generic_mul 0 0 0 in
  Alcotest.(check bool)
    "2 * 4 = 7 should fail" true
    (Common.is_error (fun () -> test_generic_mul ~cs 2 4 7))

let () =
  let open Alcotest in
  run "Generic gadgets"
    [ ( "Add gadget"
      , [ test_case "0 + 0 = 0" `Quick test_add_zero_plus_zero
        ; test_case "1 + 2 = 3" `Quick test_add_one_plus_two
        ; test_case "1 + 0 != 0 (negative)" `Quick
            test_add_negative_wrong_result
        ; test_case "2 + 4 != 7 (negative)" `Quick test_add_negative_wrong_sum
        ] )
    ; ( "Sub gadget"
      , [ test_case "0 - 0 = 0" `Quick test_sub_zero_minus_zero
        ; test_case "2 - 1 = 1" `Quick test_sub_two_minus_one
        ; test_case "4 - 2 != 1 (negative)" `Quick
            test_sub_negative_wrong_result
        ; test_case "13 - 4 != 10 (negative)" `Quick
            test_sub_negative_wrong_difference
        ] )
    ; ( "Mul gadget"
      , [ test_case "0 * 0 = 0" `Quick test_mul_zero_times_zero
        ; test_case "1 * 2 = 2" `Quick test_mul_one_times_two
        ; test_case "1 * 0 != 1 (negative)" `Quick
            test_mul_negative_wrong_result
        ; test_case "2 * 4 != 7 (negative)" `Quick
            test_mul_negative_wrong_product
        ] )
    ]
