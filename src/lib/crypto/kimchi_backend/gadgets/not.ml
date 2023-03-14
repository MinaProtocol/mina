open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* NOT *)

(* Boolean Not of length bits for checked length (uses Xor gadgets inside) *)
let bnot_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  let all_ones = Field.of_int (Int.pow 2 length - 1) in

  (* Negating is equivalent to XORing with all one word *)
  Xor.xor input all_ones length

(* Boolean Not of length bits for unchecked length (uses Generic subtractions inside) *)
let bnot_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  let all_ones = Field.of_int (Int.pow 2 length - 1) in

  (* Negating is equivalent to subtracting with all one word *)
  with_label "not_subtraction" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, all_ones)
                 ; r = (Field.Constant.Field.(to_constant (negate one)), input)
                 ; o =
                     ( Option.value_exn Field.(to_constant (negate one))
                     , all_ones - input )
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } )

(* Not of 64 bits checked *)
let bnot64_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  let open Circuit in
  bnot_checked input 64

(* Not of 64 bits unchecked *)
let bnot64_unchecked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  let open Circuit in
  bnot_unchecked input 64

let%test_unit "not gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () = Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] in

  (* Helper to test not gadget with both checked and unchecked length procedures
     *   Input and expected output and desired length : not(input) = output
     *   Returns true if constraints are satisfied, false otherwise.
  *)
  let test_not left output length =
    try
      let _proof_keypair, _proof =
        Runner.generate_and_verify_proof (fun () ->
            let open Runner.Impl in
            (* Set up snarky variables for input and output *)
            let input =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int input)
            in
            let output =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int output)
            in
            (* Use the not gate gadget *)
            let result_checked =
              bnot_checked (module Runner.Impl) input length
            in
            let result_unchecked =
              bnot_unchecked (module Runner.Impl) input length
            in
            (* Check that the result is correct *)
            Field.Assert.equal output result_checked ;
            Field.Assert.equal output result_unchecked )
      in
      true
    with _ -> false
  in

  (* Positive tests *)
  let zero = Field.zero in
  let one = Field.one in
  assert (Bool.equal (test_not zero one 1) true) ;
  assert (Bool.equal (test_not zero Field.of_int 15 4) true) ;
  assert (Bool.equal (test_not zero Field.of_int 255 8) true) ;
  assert (Bool.equal (test_not zero Field.of_int 2047 11) true) ;
  assert (Bool.equal (test_not zero Field.of_int 65535 16) true) ;
  assert (Bool.equal (test_not Field.of_int 43210 Field.of_int 22325 16) true) ;
  assert (Bool.equal (test_not Field.of_int 767430 Field.of_int 281145 20) true) ;
  (* not 0xA5A5A5A5A5A5A5A5 = 0x5A5A5A5A5A5A5A5A*)
  assert (
    Bool.equal
      (test_not Common.field_from_base10 "6510615555426900570"
         Common.field_from_base10 "18446744073709551615" 64 )
      true ) ;
  (* not 0x5A5A5A5A5A5A5A5A = 0xA5A5A5A5A5A5A5A5 *)
  assert (
    Bool.equal
      (test_not Common.field_from_base10 "18446744073709551615"
         Common.field_from_base10 "6510615555426900570" 64 )
      true ) ;
  (* not 0xFFFFFFFFFFFFFFFF = 0 *)
  assert (
    Bool.equal
      (test_not Common.field_from_base10 "72057594037927935" zero 64)
      true ) ;

  (* Negatve tests *)
  assert (Bool.equal (test_not zero zero 1) false) ;
  ()
