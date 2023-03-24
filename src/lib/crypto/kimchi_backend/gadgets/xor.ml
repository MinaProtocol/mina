open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

(* XOR *)

(* Boolean Xor of length bits *)
let bxor (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) (length : int)
    (len_xor : int) : Circuit.Field.t =
  (* Recursively builds Xor *)
  let rec bxor_rec (input1_bits : bool list) (input2_bits : bool list)
      (output_bits : bool list) (length : int) (len_xor : int) =
    let open Circuit in
    (* Transform to field elements *)
    let input1 = Field.Constant.project input1_bits in
    let input2 = Field.Constant.project input2_bits in
    let output = Field.Constant.project output_bits in
    (* If inputs are zero and length is zero, add the zero check *)
    if length = 0 then (
      assert (Field.Constant.(equal input1 zero)) ;
      assert (Field.Constant.(equal input2 zero)) ;
      assert (Field.Constant.(equal output zero)) ;
      with_label "zero_check" (fun () ->
          assert_
            { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Basic
                     { force = Field.Constant.one
                     ; l = (Field.Constant.zero, Field.one)
                     ; r = (Field.Constant.zero, Field.zero)
                     ; o =
                         (Option.value_exn Field.(to_constant zero), Field.zero)
                     ; m = Field.Constant.zero
                     ; c = Field.Constant.one
                     } )
            } ) )
    else
      (* Nibbles *)
      let first = len_xor in
      let second = first + len_xor in
      let third = second + len_xor in
      let fourth = third + len_xor in
      (* If length is more than 0, add the Xor gate *)
      with_label "xor_gate" (fun () ->
          (* Set up Xor gate *)
          assert_
            { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Xor
                     { in1 = Field.constant input1
                     ; in2 = Field.constant input2
                     ; out = Field.constant output
                     ; in1_0 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input1 0 first )
                     ; in1_1 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input1 first second )
                     ; in1_2 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input1 second third )
                     ; in1_3 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input1 third fourth )
                     ; in2_0 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input2 0 first )
                     ; in2_1 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input2 first second )
                     ; in2_2 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input2 second third )
                     ; in2_3 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              input2 third fourth )
                     ; out_0 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              output 0 first )
                     ; out_1 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              output first second )
                     ; out_2 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              output second third )
                     ; out_3 =
                         Common.field_to_cvar_field
                           (module Circuit)
                           (Common.field_bits_le_to_field
                              (module Circuit)
                              output third fourth )
                     } )
            } ) ;

      (* Remove least significant 4 nibbles *)
      let next_in1 = List.drop input1_bits fourth in
      let next_in2 = List.drop input2_bits fourth in
      let next_out = List.drop output_bits fourth in
      (* Next length is 4*n less bits *)
      let next_length = length - fourth in

      (* Recursively call xor on the next nibble *)
      bxor_rec next_in1 next_in2 next_out next_length len_xor ;
      ()
  in

  let open Circuit in
  let open Common in
  (* Check that the length fits in the field *)
  assert (length <= Field.size_in_bits) ;

  (* Sanity checks about lengths of inputs using bignum *)
  as_prover (fun () ->
      (* Convert to field type *)
      let input1_field =
        Common.cvar_field_to_field_as_prover (module Circuit) input1
      in
      let input2_field =
        Common.cvar_field_to_field_as_prover (module Circuit) input2
      in

      (* Transform to big integer *)
      let input1_big =
        Common.field_to_bignum_bigint (module Circuit) input1_field
      in
      let input2_big =
        Common.field_to_bignum_bigint (module Circuit) input2_field
      in

      (* Check real lengths are at most the desired length *)
      let two_big = Bignum_bigint.of_int 2 in
      let length_big = Bignum_bigint.of_int length in

      (* Checks inputs are smaller than 2^length *)
      assert (Bignum_bigint.(input1_big < pow two_big length_big)) ;
      assert (Bignum_bigint.(input2_big < pow two_big length_big)) ;

      (* Checks inputs fit in field *)
      assert (Bignum_bigint.(input1_big < Field.size)) ;
      assert (Bignum_bigint.(input2_big < Field.size)) ;
      () ) ;

  (* print the list of bits *)
  let _print_bits bits =
    List.iter bits ~f:(fun b -> print_string (if b then "1" else "0"))
  in

  let output_xor =
    exists Field.typ ~compute:(fun () ->
        (* Read inputs *)
        let input1_field = As_prover.read Field.typ input1 in
        let input2_field = As_prover.read Field.typ input2 in

        (* Convert inputs field elements to list of bits *)
        let input1_bits =
          field_to_bits_le_as_prover (module Circuit) input1_field
        in
        let input2_bits =
          field_to_bits_le_as_prover (module Circuit) input2_field
        in

        (* Pad with zeros in MSB until reaching same length *)
        let input1_bits = Common.pad_upto ~length ~value:false input1_bits in
        let input2_bits = Common.pad_upto ~length ~value:false input2_bits in

        (* Pad with more zeros until the length is a multiple of 4*n for n-bit length lookup table *)
        let pad_length =
          if length mod (4 * len_xor) <> 0 then
            length + (4 * len_xor) - (length mod (4 * len_xor))
          else length
        in
        let input1_bits =
          Common.pad_upto ~length:pad_length ~value:false input1_bits
        in
        let input2_bits =
          Common.pad_upto ~length:pad_length ~value:false input2_bits
        in

        (* Xor list of bits to obtain output of the xor *)
        let output_bits =
          List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 ->
              Bool.(not (equal b1 b2)) )
        in
        (* Recursively build Xor gadget *)
        bxor_rec input1_bits input2_bits output_bits pad_length len_xor ;

        (* Convert back to field *)
        Field.Constant.project output_bits )
  in

  output_xor

(* Xor of 16 bits *)
let bxor16 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  bxor (module Circuit) input1 input2 16 4

(* Xor of 64 bits *)
let bxor64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  bxor (module Circuit) input1 input2 64 4

let%test_unit "xor gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test Xor gadget
     *   Inputs operands and expected output: left_input xor right_input
     *   Returns true if constraints are satisfied, false otherwise.
  *)
  let test_xor left_input right_input output_xor length : unit =
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for inputs and output *)
          let left_input =
            Common.as_prover_cvar_field_of_base10
              (module Runner.Impl)
              left_input
          in
          let right_input =
            Common.as_prover_cvar_field_of_base10
              (module Runner.Impl)
              right_input
          in
          let output_xor =
            Common.as_prover_cvar_field_of_base10
              (module Runner.Impl)
              output_xor
          in
          (* Use the xor gate gadget *)
          let result =
            bxor (module Runner.Impl) left_input right_input length 4
          in
          Field.Assert.equal output_xor result ;
          (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
          Boolean.Assert.is_true (Field.equal result result) )
    in
    ()
  in

  let test_2xor left1 right1 output1 left2 right2 output2 length : unit =
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for inputs and output *)
          let left1 =
            Common.as_prover_cvar_field_of_base10 (module Runner.Impl) left1
          in
          let right1 =
            Common.as_prover_cvar_field_of_base10 (module Runner.Impl) right1
          in
          let output1 =
            Common.as_prover_cvar_field_of_base10 (module Runner.Impl) output1
          in
          let left2 =
            Common.as_prover_cvar_field_of_base10 (module Runner.Impl) left2
          in
          let right2 =
            Common.as_prover_cvar_field_of_base10 (module Runner.Impl) right2
          in
          let output2 =
            Common.as_prover_cvar_field_of_base10 (module Runner.Impl) output2
          in
          (* Use the xor gate gadget *)
          let result1 = bxor (module Runner.Impl) left1 right1 length 4 in
          let result2 = bxor (module Runner.Impl) left2 right2 length 4 in
          Field.Assert.equal output1 result1 ;
          Field.Assert.equal output2 result2 ;
          Boolean.Assert.is_true (Field.equal result1 result1) )
    in
    ()
  in

  (* Positive tests *)
  test_xor "1" "0" "1" 16 ;
  test_xor "0" "0" "0" 8 ;
  test_xor "0" "0" "0" 1 ;
  test_xor "0" "0" "0" 4 ;
  test_xor "43210" "56789" "29983" 16 ;
  test_xor "767430" "974317" "354347" 20 ;
  (* 0x5A5A5A5A5A5A5A5A xor 0xA5A5A5A5A5A5A5A5 = 0xFFFFFFFFFFFFFFFF*)
  test_xor "6510615555426900570" "11936128518282651045" "18446744073709551615"
    64 ;
  test_2xor "43210" "56789" "29983" "767430" "974317" "354347" 20 ;
  (* Negatve tests *)
  assert (Common.is_error (fun () -> test_xor "1" "0" "0" 1)) ;
  assert (Common.is_error (fun () -> test_xor "1111" "2222" "0" 16)) ;
  assert (Common.is_error (fun () -> test_xor "0" "0" "0" 256)) ;

  ()
