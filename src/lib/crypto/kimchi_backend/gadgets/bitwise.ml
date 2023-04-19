open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

(* Auxiliary functions *)

(* returns a field containing the all one word of length bits *)
let cvar_field_all_ones (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (length : int) : Circuit.Field.t =
  let open Circuit in
  exists Field.typ ~compute:(fun () ->
      Common.bignum_bigint_to_field (module Circuit)
      @@ Bignum_bigint.(pow (of_int 2) (of_int length) - one) )

(* ROT64 *)

(* Side of rotation *)
type rot_mode = Left | Right

(* 64-bit Rotation of rot_bits to the `mode` side
   *  - word of maximum 64 bits to be rotated
   * - rot_bits: number of bits to be rotated
   * - mode: Left or Right
   * Returns rotated word
*)
let rot_64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (word : Circuit.Field.t) (rot_bits : int) (mode : rot_mode) :
    Circuit.Field.t =
  let open Circuit in
  (* Check that the rotation bits is smaller than 64 *)
  assert (rot_bits < 64) ;
  (* Check that the rotation bits is non-negative *)
  assert (rot_bits >= 0) ;

  (* Compute actual length depending on whether the rotation mode is Left or Right *)
  let rot_bits = match mode with Left -> rot_bits | Right -> 64 - rot_bits in

  (* Auxiliary Bignum_bigint values *)
  let big_2_pow_64 = Bignum_bigint.(pow (of_int 2) (of_int 64)) in
  let big_2_pow_rot = Bignum_bigint.(pow (of_int 2) (of_int rot_bits)) in

  (* Compute the rotated word *)
  let values =
    exists (Typ.array ~length:4 Field.typ) ~compute:(fun () ->
        (* Assert that word is at most 64 bits*)
        let word_big =
          Common.(
            field_to_bignum_bigint
              (module Circuit)
              (cvar_field_to_field_as_prover (module Circuit) word))
        in
        assert (Bignum_bigint.(word_big < big_2_pow_64)) ;

        (* Obtain rotated output, excess, and shifted for the equation
             word * 2^rot = excess * 2^64 + shifted *)
        let excess_big, shifted_big =
          Common.bignum_bigint_div_rem
            Bignum_bigint.(word_big * big_2_pow_rot)
            big_2_pow_64
        in

        (* Compute rotated value as
           rotated = excess + shifted *)
        let rotated_big = Bignum_bigint.(shifted_big + excess_big) in

        (* Compute bound that is the right input of FFAdd equation *)
        let bound_big =
          Bignum_bigint.(excess_big + big_2_pow_64 - big_2_pow_rot)
        in

        (* Convert back to field *)
        let shifted =
          Common.bignum_bigint_to_field (module Circuit) shifted_big
        in
        let excess =
          Common.bignum_bigint_to_field (module Circuit) excess_big
        in
        let rotated =
          Common.bignum_bigint_to_field (module Circuit) rotated_big
        in
        let bound = Common.bignum_bigint_to_field (module Circuit) bound_big in

        [| rotated; excess; shifted; bound |] )
  in

  let rotated = values.(0) in
  let excess = values.(1) in
  let shifted = values.(2) in
  let bound = values.(3) in

  let of_bits =
    Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
  in

  (* Current row *)
  with_label "rot64_gate" (fun () ->
      (* Set up Rot64 gate *)
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Rot64
                 { word
                 ; rotated
                 ; excess
                 ; bound_limb0 = of_bits bound 52 64
                 ; bound_limb1 = of_bits bound 40 52
                 ; bound_limb2 = of_bits bound 28 40
                 ; bound_limb3 = of_bits bound 16 28
                 ; bound_crumb0 = of_bits bound 14 16
                 ; bound_crumb1 = of_bits bound 12 14
                 ; bound_crumb2 = of_bits bound 10 12
                 ; bound_crumb3 = of_bits bound 8 10
                 ; bound_crumb4 = of_bits bound 6 8
                 ; bound_crumb5 = of_bits bound 4 6
                 ; bound_crumb6 = of_bits bound 2 4
                 ; bound_crumb7 = of_bits bound 0 2
                 ; two_to_rot =
                     Common.bignum_bigint_to_field
                       (module Circuit)
                       big_2_pow_rot
                 } )
        } ) ;

  (* Next row *)
  Range_check.bits64 (module Circuit) shifted ;
  rotated

(* XOR *)

(* Boolean Xor of length bits
 * input1 and input2 are the inputs to the Xor gate
  * length is the number of bits to Xor
  * len_xor is the number of bits of the lookup table (default is 4)
 *)
let bxor (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(len_xor = 4) (input1 : Circuit.Field.t) (input2 : Circuit.Field.t)
    (length : int) : Circuit.Field.t =
  (* Recursively builds Xor
     * input1_bits and input2_bits are the inputs to the Xor gate as bits
     * output_bits is the output of the Xor gate as bits
     * length is the number of remaining bits to Xor
     * len_xor is the number of bits of the lookup table (default is 4)
  *)
  let rec bxor_rec (input1_bits : bool list) (input2_bits : bool list)
      (output_bits : bool list) (length : int) (len_xor : int) =
    let open Circuit in
    (* Transform to field *)

    (* TODO: [Anais] concerned that at circuit creation time these will be constants
     *       thus the Xor and Zero gates' cvars below will be constant field cvars
     *       resulting in extra generic gates with these constatnts baked into coeffs
     *)
    let input1 = Field.Constant.project input1_bits in
    let input2 = Field.Constant.project input2_bits in
    let output = Field.Constant.project output_bits in
    (* Convert to cvar *)
    let param_vars =
      exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
          [| input1; input2; output |] )
    in
    let input1 = param_vars.(0) in
    let input2 = param_vars.(1) in
    let output = param_vars.(2) in
    (* If inputs are zero and length is zero, add the zero check *)
    if length = 0 then (
      Field.Assert.equal Field.zero input1 ;
      Field.Assert.equal Field.zero input2 ;
      Field.Assert.equal Field.zero output ;
      with_label "xor_zero_check" (fun () ->
          assert_
            { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Raw
                     { kind = Zero
                     ; values = [| input1; input2; output |]
                     ; coeffs = [||]
                     } )
            } ) )
    else
      (* Define shorthand helper *)
      let of_bits =
        Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
      in

      (* Nibble offsets *)
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
                     { in1 = input1
                     ; in2 = input2
                     ; out = output
                     ; in1_0 = of_bits input1 0 first
                     ; in1_1 = of_bits input1 first second
                     ; in1_2 = of_bits input1 second third
                     ; in1_3 = of_bits input1 third fourth
                     ; in2_0 = of_bits input2 0 first
                     ; in2_1 = of_bits input2 first second
                     ; in2_2 = of_bits input2 second third
                     ; in2_3 = of_bits input2 third fourth
                     ; out_0 = of_bits output 0 first
                     ; out_1 = of_bits output first second
                     ; out_2 = of_bits output second third
                     ; out_3 = of_bits output third fourth
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
  (* Check that the length is positive *)
  assert (length > 0 && len_xor > 0) ;
  (* Check that the length fits in the field *)
  assert (length <= Field.size_in_bits) ;

  (* Initialize array of 255 bools all set to false *)
  let input1_array = Array.create ~len:Field.size_in_bits false in
  let input2_array = Array.create ~len:Field.size_in_bits false in

  (* Sanity checks about lengths of inputs using bignum *)
  as_prover (fun () ->
      (* Read inputs, Convert to field type *)
      let input1_field =
        cvar_field_to_field_as_prover (module Circuit) input1
      in
      let input2_field =
        cvar_field_to_field_as_prover (module Circuit) input2
      in

      (* Transform to big integer *)
      let input1_big = field_to_bignum_bigint (module Circuit) input1_field in
      let input2_big = field_to_bignum_bigint (module Circuit) input2_field in

      (* Check real lengths are at most the desired length *)
      let two_big = Bignum_bigint.of_int 2 in
      let length_big = Bignum_bigint.of_int length in

      (* Checks inputs are smaller than 2^length *)
      assert (Bignum_bigint.(input1_big < pow two_big length_big)) ;
      assert (Bignum_bigint.(input2_big < pow two_big length_big)) ;

      (* Checks inputs fit in field *)
      assert (Bignum_bigint.(input1_big < Field.size)) ;
      assert (Bignum_bigint.(input2_big < Field.size)) ;

      (* Convert inputs field elements to list of bits of length 255 *)
      let input1_bits = Field.Constant.unpack @@ input1_field in
      let input2_bits = Field.Constant.unpack @@ input2_field in

      (* Convert list of bits to arrays *)
      let input1_bits_array = List.to_array @@ input1_bits in
      let input2_bits_array = List.to_array @@ input2_bits in

      (* Iterate over 255 positions to update value of arrays *)
      for i = 0 to Field.size_in_bits - 1 do
        input1_array.(i) <- input1_bits_array.(i) ;
        input2_array.(i) <- input2_bits_array.(i)
      done ;

      () ) ;

  (* Convert array of bits to list of booleans without leading zeros *)
  let input1_bits =
    Common.bool_list_wo_zero_bits @@ Array.to_list input1_array
  in
  let input2_bits =
    Common.bool_list_wo_zero_bits @@ Array.to_list input2_array
  in

  (* Pad with zeros in MSB until reaching same length *)
  let input1_bits = pad_upto ~length ~value:false input1_bits in
  let input2_bits = pad_upto ~length ~value:false input2_bits in

  (* Pad with more zeros until the length is a multiple of 4*n for n-bit length lookup table *)
  let pad_length =
    if length mod (4 * len_xor) <> 0 then
      length + (4 * len_xor) - (length mod (4 * len_xor))
    else length
  in
  let input1_bits = pad_upto ~length:pad_length ~value:false input1_bits in
  let input2_bits = pad_upto ~length:pad_length ~value:false input2_bits in

  (* Xor list of bits to obtain output of the xor *)
  let output_bits =
    List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 ->
        Bool.(not (equal b1 b2)) )
  in

  (* Recursively build Xor gadget *)
  bxor_rec input1_bits input2_bits output_bits pad_length len_xor ;

  (* Convert back to field *)
  exists Field.typ ~compute:(fun () -> Field.Constant.project output_bits)

(* Boolean Xor of 16 bits
 * This is a special case of Xor for 16 bits for Xor lookup table of 4 bits of inputs.
 * Receives two input words to Xor together, of maximum 16 bits each.
 * Returns the Xor of the two words.
 *)
let bxor16 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  bxor (module Circuit) input1 input2 16 ~len_xor:4

(* Boolean Xor of 64 bits
 * This is a special case of Xor for 64 bits for Xor lookup table of 4 bits of inputs.
 * Receives two input words to Xor together, of maximum 64 bits each.
 * Returns the Xor of the two words.
 *)
let bxor64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  bxor (module Circuit) input1 input2 64 ~len_xor:4

(* AND *)

(* Boolean And of length bits
   *  input1 and input2 are the two inputs to AND
   *  length is the number of bits to AND
   *  len_xor is the number of bits of the inputs of the Xor lookup table (default is 4)
*)
let band (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(len_xor = 4) (input1 : Circuit.Field.t) (input2 : Circuit.Field.t)
    (length : int) : Circuit.Field.t =
  let open Circuit in
  (* Recursively build And gadget with leading Xors and a final Generic gate *)
  (* It will also check the correct lengths of the inputs, no need to do it again *)
  let xor_output = bxor (module Circuit) input1 input2 length ~len_xor in
  (* Transform to non constant cvar *)
  (* TODO: [Anais] once bxor is fixed not to create const cvars, below should not be needed *)
  let xor_output_var =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_to_field_as_prover (module Circuit) xor_output )
  in

  let and_output =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_bits_combine_as_prover
          (module Circuit)
          input1 input2
          (fun b1 b2 -> b1 && b2) )
  in

  (* Compute sum of a + b and constrain in the circuit *)
  let sum = Generic.add (module Circuit) input1 input2 in
  (* TODO: [Anais] this should already be non-const cvar *)
  (* Transform to non constant cvar *)
  let sum_var =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_to_field_as_prover (module Circuit) sum )
  in

  let two = Field.of_int 2 in

  (* Constrain AND as 2 * and = sum - xor *)
  with_label "and_equation" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, sum_var)
                 ; r =
                     ( Option.value_exn Field.(to_constant (negate one))
                     , xor_output_var )
                 ; o =
                     ( Option.value_exn Field.(to_constant (negate two))
                     , and_output )
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } ) ;

  and_output

(* Boolean And of 64 bits
 * This is a special case of And for 64 bits for Xor lookup table of 4 bits of inputs.
 * Receives two input words to And together, of maximum 64 bits each.
 * Returns the And of the two words.
 *)
let band64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  band (module Circuit) input1 input2 64

(* NOT *)

(* Boolean Not of length bits for checked length (uses Xor gadgets inside to constrain the length)
    *   - input of word to negate
    *   - length of word to negate
    *   - len_xor is the length of the Xor lookup table to use beneath (default 4)
*)
let bnot_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(len_xor = 4) (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let all_ones_var = cvar_field_all_ones (module Circuit) length in

  (* Negating is equivalent to XORing with all one word *)
  bxor (module Circuit) input all_ones_var length ~len_xor

(* Negates a word of 64 bits with checked length of 64 bits.
   * This means that the bound in lenght is constrained in the circuit. *)
let bnot64_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_checked (module Circuit) input 64

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
  let all_ones_var = cvar_field_all_ones (module Circuit) length in
  let not_output = Field.(all_ones_var - input) in
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
                     , not_output )
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } ) ;
  not_output

(* Negates a word of 64 bits, but its length goes unconstrained in the circuit
   (unless it is copied from a checked length value) *)
let bnot64_unchecked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_unchecked (module Circuit) input 64

(* UNIT TESTS *)

let%test_unit "bitwise rotation gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test Rot gadget
     *   Input operands and expected output: word len mode rotated
     *   Returns unit if constraints are satisfied, error otherwise.
  *)
  let test_rot word length mode result : unit =
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for inputs and output *)
          let word =
            exists Field.typ ~compute:(fun () -> Field.Constant.of_string word)
          in
          let result =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string result )
          in
          (* Use the xor gate gadget *)
          let output_rot = rot_64 (module Runner.Impl) word length mode in
          Field.Assert.equal output_rot result ;
          (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
          Boolean.Assert.is_true (Field.equal output_rot output_rot) )
    in
    ()
  in

  (* Positive tests *)
  test_rot "0" 0 Left "0" ;
  test_rot "0" 32 Right "0" ;
  test_rot "1" 1 Left "2" ;
  test_rot "1" 63 Left "9223372036854775808" ;
  test_rot "256" 4 Right "16" ;
  test_rot "1234567890" 32 Right "5302428712241725440" ;
  (* 0x5A5A5A5A5A5A5A5A is 0xA5A5A5A5A5A5A5A5 both when rotate 4 bits Left or Right*)
  test_rot "6510615555426900570" 4 Left "11936128518282651045" ;
  test_rot "6510615555426900570" 4 Right "11936128518282651045" ;

  (* Negatve tests *)
  assert (Common.is_error (fun () -> test_rot "0" 1 Left "1")) ;
  assert (Common.is_error (fun () -> test_rot "1" 64 Left "1")) ;
  ()

let%test_unit "bitwise xor gadget" =
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
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for inputs and output *)
          let left_input =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string left_input )
          in
          let right_input =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string right_input )
          in
          let output_xor =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string output_xor )
          in
          (* Use the xor gate gadget *)
          let result =
            bxor (module Runner.Impl) left_input right_input length
          in

          (* Check that the result is equal to the expected output *)
          Field.Assert.equal output_xor result )
    in
    ()
  in

  let test_2xor left1 right1 output1 left2 right2 output2 length : unit =
    test_xor left1 right1 output1 length ;
    test_xor left2 right2 output2 length ;
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
  assert (Common.is_error (fun () -> test_xor "0" "0" "0" (-4))) ;

  ()

let%test_unit "bitwise and gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in
  (* Helper to test And gadget
     *   Inputs operands and expected output: left_input and right_input = output
     *   Returns true if constraints are satisfied, false otherwise.
  *)
  let test_and left_input right_input output_and length =
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for inputs and outputs *)
          let left_input =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string left_input )
          in
          let right_input =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string right_input )
          in
          let output_and =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string output_and )
          in
          (* Use the and gate gadget *)
          let result =
            band (module Runner.Impl) left_input right_input length
          in
          Field.Assert.equal output_and result )
    in
    ()
  in

  (* Positive tests *)
  test_and "0" "0" "0" 16 ;
  test_and "0" "0" "0" 8 ;
  test_and "1" "1" "1" 1 ;
  test_and "15" "15" "15" 4 ;
  test_and "1111" "2222" "6" 16 ;
  test_and "43210" "56789" "35008" 16 ;
  test_and "767430" "974317" "693700" 20 ;
  (* 0x5A5A5A5A5A5A5A5A and 0xA5A5A5A5A5A5A5A5 = 0x0000000000000000*)
  test_and "6510615555426900570" "11936128518282651045" "0" 64 ;
  (* Negatve tests *)
  assert (Common.is_error (fun () -> test_and "1" "1" "0" 1)) ;
  assert (Common.is_error (fun () -> test_and "255" "255" "255" 7)) ;
  assert (Common.is_error (fun () -> test_and "1" "1" "1" (-1))) ;
  ()

let%test_unit "bitwise not gadget" =
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
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for input and output *)
          let input =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string input )
          in

          let output =
            exists Field.typ ~compute:(fun () ->
                Field.Constant.of_string output )
          in

          (* Use the not gate gadget *)
          let result_checked = bnot_checked (module Runner.Impl) input length in
          let result_unchecked =
            bnot_unchecked (module Runner.Impl) input length
          in
          Field.Assert.equal output result_checked ;
          Field.Assert.equal output result_unchecked )
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
