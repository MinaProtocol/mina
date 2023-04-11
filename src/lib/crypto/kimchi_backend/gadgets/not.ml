open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

(* NOT *)

(* Boolean Not of length bits for checked length (uses Xor gadgets inside to constrain the length)
    *   - input of word to negate
    *   - length of word to negate
    *   - len_xor is the length of the Xor lookup table to use beneath (default 4)
*)
let bnot_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(len_xor = 4) (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  let all_ones = Bignum_bigint.(pow (of_int 2) (of_int length) - one) in
  let all_ones = Common.bignum_bigint_to_field (module Circuit) all_ones in
  let all_ones = Field.constant all_ones in
  let all_ones_var =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_to_field_as_prover (module Circuit) all_ones )
  in
  Field.Assert.equal all_ones all_ones_var ;

  (* Negating is equivalent to XORing with all one word *)
  Xor.bxor (module Circuit) input all_ones length ~len_xor

(* Boolean Not of length bits for unchecked length (uses Generic subtractions inside) 
 *  - input of word to negate
 *  - length of word to negate
 * (Note that this can negate two words per row, but it inputs need to be a copy of another
 variable with a correct length in order to make sure that the length is correct )   
 *)
let bnot_unchecked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  let all_ones = Bignum_bigint.(pow (of_int 2) (of_int length) - one) in
  let all_ones = Common.bignum_bigint_to_field (module Circuit) all_ones in
  let all_ones = Field.constant all_ones in
  let all_ones_var =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_to_field_as_prover (module Circuit) all_ones )
  in
  Field.Assert.equal all_ones all_ones_var ;
  (* Negating is equivalent to subtracting with all one word *)
  (* [2^len - 1] - input = not (input) *)
  with_label "not_subtraction" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, all_ones_var)
                 ; r = (Option.value_exn Field.(to_constant (negate one)), input)
                 ; o =
                     ( Option.value_exn Field.(to_constant (negate one))
                     , Field.(all_ones_var - input) )
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } ) ;
  Field.(all_ones_var - input)

(* Negates a word of 64 bits with checked length of 64 bits *)
let bnot64_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_checked (module Circuit) input 64

(* Negates a word of 64 bits, but its length goes unconstrained *)
let bnot64_unchecked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_unchecked (module Circuit) input 64

let%test_unit "not gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in
  (* Helper to test not gadget with both checked and unchecked length procedures
     *   Input and expected output and desired length : not(input) = output
     *   Returns true if constraints are satisfied, false otherwise.
  *)
  let test_not input output length =
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for input and output *)
          let input =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string input )
          in
          (* TODO: fix this misbehaviour in permutation code:
           * Intentionally duplicating this variable twice because 
           * otherwise it causes a final permutation error when
           * reusing the same output to compare the three values:
           *   - result_checked
           *   - result_unchecked
          *   - output
           *)
          let output =
            exists (Typ.array ~length:2 Field.typ) ~compute:(fun () ->
                let cvar = Field.Constant.of_string output in
                [| cvar; cvar |] )
          in

          (* Use the not gate gadget *)
          let result_checked = bnot_checked (module Runner.Impl) input length in
          let result_unchecked =
            bnot_unchecked (module Runner.Impl) input length
          in
          Field.Assert.equal output.(0) result_checked ;
          Field.Assert.equal output.(1) result_unchecked )
    in
    ()
  in
  
  (* Positive tests *)
  test_not "0" "1" 1 ;
  test_not "0" "15" 4 ;
  test_not "0" "255" 8 ;
  test_not "0" "2047" 11 ;
  test_not "0" "65535" 16 ;
  test_not "43210" "22325" 16 ;
  test_not "767430" "281145" 20 ;
  (* not 0xA5A5A5A5A5A5A5A5 = 0x5A5A5A5A5A5A5A5A*)
  test_not "11936128518282651045" "6510615555426900570" 64 ;
  (* not 0x5A5A5A5A5A5A5A5A = 0xA5A5A5A5A5A5A5A5 *)
  test_not "6510615555426900570" "11936128518282651045" 64 ;
  (* not 0xFFFFFFFFFFFFFFFF = 0 *)
  test_not "18446744073709551615" "0" 64 ;

  (* Negatve tests *)
  assert (Common.is_error (fun () -> test_not "0" "0" 1)) ;
  assert (Common.is_error (fun () -> test_not "255" "0" 4)) ;
  ()
