open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

let tests_enabled = true

(* Auxiliary functions *)

(* returns a field containing the all one word of length bits *)
let all_ones_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (length : int) : f =
  Common.bignum_bigint_to_field (module Circuit)
  @@ Bignum_bigint.(pow (of_int 2) (of_int length) - one)

let fits_in_bits_as_prover (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (word : Circuit.Field.t) (length : int) =
  let open Common in
  assert (
    Bignum_bigint.(
      field_to_bignum_bigint
        (module Circuit)
        (cvar_field_to_field_as_prover (module Circuit) word)
      < pow (of_int 2) (of_int length)) )

(* ROT64 *)

(* Side of rotation *)
type rot_mode = Left | Right

(* Performs the 64bit rotation and returns rotated word, excess, and shifted *)
let rot_aux (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(check64 = false) (word : Circuit.Field.t) (bits : int) (mode : rot_mode) :
    Circuit.Field.t * Circuit.Field.t * Circuit.Field.t =
  let open Circuit in
  (* Check that the rotation bits is smaller than 64 *)
  assert (bits < 64) ;
  (* Check that the rotation bits is non-negative *)
  assert (bits >= 0) ;

  (* Check that the input word has at most 64 bits *)
  as_prover (fun () ->
      fits_in_bits_as_prover (module Circuit) word 64 ;
      () ) ;

  (* Compute actual length depending on whether the rotation mode is Left or Right *)
  let rot_bits = match mode with Left -> bits | Right -> 64 - bits in

  (* Auxiliary Bignum_bigint values *)
  let big_2_pow_64 = Bignum_bigint.(pow (of_int 2) (of_int 64)) in
  let big_2_pow_rot = Bignum_bigint.(pow (of_int 2) (of_int rot_bits)) in

  (* Compute the rotated word *)
  let rotated, excess, shifted, bound =
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
    |> Common.tuple4_of_array
  in

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
                 ; shifted
                 ; shifted_limb0 = of_bits shifted 52 64
                 ; shifted_limb1 = of_bits shifted 40 52
                 ; shifted_limb2 = of_bits shifted 28 40
                 ; shifted_limb3 = of_bits shifted 16 28
                 ; shifted_crumb0 = of_bits shifted 14 16
                 ; shifted_crumb1 = of_bits shifted 12 14
                 ; shifted_crumb2 = of_bits shifted 10 12
                 ; shifted_crumb3 = of_bits shifted 8 10
                 ; shifted_crumb4 = of_bits shifted 6 8
                 ; shifted_crumb5 = of_bits shifted 4 6
                 ; shifted_crumb6 = of_bits shifted 2 4
                 ; shifted_crumb7 = of_bits shifted 0 2
                 ; two_to_rot =
                     Common.bignum_bigint_to_field
                       (module Circuit)
                       big_2_pow_rot
                 } )
        } ) ;

  (* Next row *)
  Range_check.bits64 (module Circuit) shifted ;

  (* Following row *)
  Range_check.bits64 (module Circuit) excess ;

  if check64 then Range_check.bits64 (module Circuit) word ;

  (rotated, excess, shifted)

(* 64-bit Rotation of rot_bits to the `mode` side
 *   Inputs
 *     - check: whether to check the input word is at most 64 bits (default is false)
 *     - word of maximum 64 bits to be rotated
 *     - rot_bits: number of bits to be rotated
 *     - mode: Left or Right
 * Output: rotated word
 *)
let rot64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(check64 : bool = false) (word : Circuit.Field.t) (rot_bits : int)
    (mode : rot_mode) : Circuit.Field.t =
  let rotated, _excess, _shifted =
    rot_aux (module Circuit) ~check64 word rot_bits mode
  in

  rotated

(* 64-bit bitwise logical shift of bits to the left side
 * Inputs
 *  - check64: whether to check the input word is at most 64 bits (default is false)
 *  - word of maximum 64 bits to be shifted
 *  - bits: number of bits to be shifted
 * Output: left shifted word (with bits 0s at the least significant positions)
 *)
let lsl64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(check64 : bool = false) (word : Circuit.Field.t) (bits : int) :
    Circuit.Field.t =
  let _rotated, _excess, shifted =
    rot_aux (module Circuit) ~check64 word bits Left
  in

  shifted

(* 64-bit bitwise logical shift of bits to the right side
   * Inputs
   *  - check64: whether to check the input word is at most 64 bits (default is false)
   *  - word of maximum 64 bits to be shifted
   *  - bits: number of bits to be shifted
   * Output: right shifted word (with bits 0s at the most significant positions)
*)
let lsr64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(check64 : bool = false) (word : Circuit.Field.t) (bits : int) :
    Circuit.Field.t =
  let _rotated, excess, _shifted =
    rot_aux (module Circuit) ~check64 word bits Right
  in

  excess

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
  (* Auxiliar function to compute the next variable for the chain of Xors *)
  let as_prover_next_var (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (curr_var : Circuit.Field.t) (var0 : Circuit.Field.t)
      (var1 : Circuit.Field.t) (var2 : Circuit.Field.t) (var3 : Circuit.Field.t)
      (len_xor : int) : Circuit.Field.t =
    let open Circuit in
    let two_pow_len =
      Common.bignum_bigint_to_field
        (module Circuit)
        Bignum_bigint.(pow (of_int 2) (of_int len_xor))
    in
    let two_pow_2len = Field.Constant.(two_pow_len * two_pow_len) in
    let two_pow_3len = Field.Constant.(two_pow_2len * two_pow_len) in
    let two_pow_4len = Field.Constant.(two_pow_3len * two_pow_len) in
    let next_var =
      exists Field.typ ~compute:(fun () ->
          let curr_field =
            Common.cvar_field_to_field_as_prover (module Circuit) curr_var
          in
          let field0 =
            Common.cvar_field_to_field_as_prover (module Circuit) var0
          in
          let field1 =
            Common.cvar_field_to_field_as_prover (module Circuit) var1
          in
          let field2 =
            Common.cvar_field_to_field_as_prover (module Circuit) var2
          in
          let field3 =
            Common.cvar_field_to_field_as_prover (module Circuit) var3
          in
          Field.Constant.(
            ( curr_field - field0 - (field1 * two_pow_len)
            - (field2 * two_pow_2len) - (field3 * two_pow_3len) )
            / two_pow_4len) )
    in
    next_var
  in

  (* Recursively builds Xor
   * input1and input2 are the inputs to the Xor gate as bits
   * output is the output of the Xor gate as bits
   * length is the number of remaining bits to Xor
   * len_xor is the number of bits of the lookup table (default is 4)
   *)
  let rec bxor_rec (in1 : Circuit.Field.t) (in2 : Circuit.Field.t)
      (out : Circuit.Field.t) (length : int) (len_xor : int) =
    let open Circuit in
    (* If inputs are zero and length is zero, add the zero check *)
    if length = 0 then (
      with_label "xor_zero_check" (fun () ->
          assert_
            { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Raw
                     { kind = Zero
                     ; values = [| in1; in2; out |]
                     ; coeffs = [||]
                     } )
            } ) ;
      Field.Assert.equal Field.zero in1 ;
      Field.Assert.equal Field.zero in2 ;
      Field.Assert.equal Field.zero out ;
      () )
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

      let in1_0 = of_bits in1 0 first in
      let in1_1 = of_bits in1 first second in
      let in1_2 = of_bits in1 second third in
      let in1_3 = of_bits in1 third fourth in
      let in2_0 = of_bits in2 0 first in
      let in2_1 = of_bits in2 first second in
      let in2_2 = of_bits in2 second third in
      let in2_3 = of_bits in2 third fourth in
      let out_0 = of_bits out 0 first in
      let out_1 = of_bits out first second in
      let out_2 = of_bits out second third in
      let out_3 = of_bits out third fourth in

      let next_in1 =
        as_prover_next_var (module Circuit) in1 in1_0 in1_1 in1_2 in1_3 len_xor
      in
      let next_in2 =
        as_prover_next_var (module Circuit) in2 in2_0 in2_1 in2_2 in2_3 len_xor
      in
      let next_out =
        as_prover_next_var (module Circuit) out out_0 out_1 out_2 out_3 len_xor
      in

      (* If length is more than 0, add the Xor gate *)
      with_label "xor_gate" (fun () ->
          (* Set up Xor gate *)
          assert_
            { annotation = Some __LOC__
            ; basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Xor
                     { in1
                     ; in2
                     ; out
                     ; in1_0
                     ; in1_1
                     ; in1_2
                     ; in1_3
                     ; in2_0
                     ; in2_1
                     ; in2_2
                     ; in2_3
                     ; out_0
                     ; out_1
                     ; out_2
                     ; out_3
                     ; next_in1
                     ; next_in2
                     ; next_out
                     } )
            } ) ;

      (* Next length is 4*n less bits *)
      let next_length = length - (4 * len_xor) in

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

      (* Check real lengths are at most the desired length *)
      fits_in_bits_as_prover (module Circuit) input1 length ;
      fits_in_bits_as_prover (module Circuit) input2 length ;

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

  let output_xor =
    exists Field.typ ~compute:(fun () ->
        (* Sanity checks about lengths of inputs using bignum *)
        (* Check real lengths are at most the desired length *)
        fits_in_bits_as_prover (module Circuit) input1 length ;
        fits_in_bits_as_prover (module Circuit) input2 length ;

        let input1_field =
          cvar_field_to_field_as_prover (module Circuit) input1
        in
        let input2_field =
          cvar_field_to_field_as_prover (module Circuit) input2
        in

        (* Convert inputs field elements to list of bits of length 255 *)
        let input1_bits = Field.Constant.unpack @@ input1_field in
        let input2_bits = Field.Constant.unpack @@ input2_field in

        (* Xor list of bits to obtain output of the xor *)
        let output_bits =
          List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 ->
              Bool.(not (equal b1 b2)) )
        in

        (* Convert list of output bits to field element *)
        Field.Constant.project output_bits )
  in

  (* Obtain pad length until the length is a multiple of 4*n for n-bit length lookup table *)
  let pad_length =
    if length mod (4 * len_xor) <> 0 then
      length + (4 * len_xor) - (length mod (4 * len_xor))
    else length
  in

  (* Recursively build Xor gadget *)
  bxor_rec input1 input2 output_xor pad_length len_xor ;

  (* Convert back to field *)
  output_xor

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

  let and_output =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_bits_combine_as_prover
          (module Circuit)
          input1 input2
          (fun b1 b2 -> b1 && b2) )
  in

  (* Compute sum of a + b and constrain in the circuit *)
  let sum = Generic.add (module Circuit) input1 input2 in
  let neg_one = Field.Constant.(negate one) in
  let neg_two = Field.Constant.(neg_one + neg_one) in

  (* Constrain AND as 2 * and = sum - xor *)
  with_label "and_equation" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, sum)
                 ; r = (neg_one, xor_output)
                 ; o = (neg_two, and_output)
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
 * Note that the length needs to be less than the bit length of the field.
 *)
let bnot_checked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(len_xor = 4) (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  (* Check it is not 255 or else 2^255-1 will not fit in Pallas *)
  assert (length < Circuit.Field.size_in_bits) ;

  let all_ones_f = all_ones_field (module Circuit) length in
  let all_ones_var = exists Field.typ ~compute:(fun () -> all_ones_f) in

  (* Negating is equivalent to XORing with all one word *)
  let out_not = bxor (module Circuit) input all_ones_var length ~len_xor in

  (* Doing this afterwards or else it can break chainability with Xor16's and Zero *)
  Field.Assert.equal (Field.constant all_ones_f) all_ones_var ;

  out_not

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
 * variable with a correct length in order to make sure that the length is correct)
 *)
let bnot_unchecked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  (* Check it is not 255 or else 2^255-1 will not fit in Pallas *)
  assert (length < Circuit.Field.size_in_bits) ;
  assert (length > 0) ;

  (* Check that the input word has at most length bits.
     In the checked version this is done in the Xor *)
  as_prover (fun () ->
      fits_in_bits_as_prover (module Circuit) input length ;
      () ) ;

  let all_ones_f = all_ones_field (module Circuit) length in
  let all_ones_var = exists Field.typ ~compute:(fun () -> all_ones_f) in
  Field.Assert.equal all_ones_var (Field.constant all_ones_f) ;

  (* Negating is equivalent to subtracting with all one word *)
  (* [2^len - 1] - input = not (input) *)
  Generic.sub (module Circuit) all_ones_var input

(* Negates a word of 64 bits, but its length goes unconstrained in the circuit
   (unless it is copied from a checked length value) *)
let bnot64_unchecked (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_unchecked (module Circuit) input 64

(**************)
(* UNIT TESTS *)
(**************)

let%test_unit "bitwise rotation gadget" =
  if tests_enabled then
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test ROT gadget
     *   Input operands and expected output: word len mode rotated
     *   Returns unit if constraints are satisfied, error otherwise.
     *   If odd is true, it inserts one initial dummy generic gate
     *)
    let test_rot ?cs ?(odd = false) word length mode result =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            ( if odd then
              (* Create half a generic to force an odd number of Generics preceding Xor *)
              let left_summand =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 15)
              in
              let right_summand =
                exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0)
              in
              Field.Assert.equal
                (Field.( + ) left_summand right_summand)
                left_summand ) ;
            (* Set up snarky variables for inputs and output *)
            let word =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string word )
            in
            let result =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string result )
            in
            (* Use the rot gate gadget *)
            let output_rot = rot64 (module Runner.Impl) word length mode in
            Field.Assert.equal output_rot result
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *) )
      in
      cs
    in
    (* Positive tests *)
    (* odd = true *)
    let _cs =
      test_rot ~odd:true "6510615555426900570" 4 Left "11936128518282651045"
    in

    let _cs = test_rot "0" 0 Left "0" in
    ()
(*
    let _cs = test_rot "0" 32 Right "0" in
    let _cs = test_rot "1" 1 Left "2" in
    let _cs = test_rot "1" 63 Left "9223372036854775808" in
    let cs = test_rot "256" 4 Right "16" in
    (* 0x5A5A5A5A5A5A5A5A is 0xA5A5A5A5A5A5A5A5 both when rotate 4 bits Left or Right*)
    let _cs =
      test_rot ~cs "6510615555426900570" 4 Right "11936128518282651045"
    in
    let _cs = test_rot "6510615555426900570" 4 Left "11936128518282651045" in
    let cs = test_rot "1234567890" 32 Right "5302428712241725440" in
    let _cs = test_rot ~cs "2651214356120862720" 32 Right "617283945" in
    let _cs = test_rot ~cs "1153202983878524928" 32 Right "268500993" in

    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_rot "0" 1 Left "1")) ;
    assert (Common.is_error (fun () -> test_rot "1" 64 Left "1")) ;
    assert (Common.is_error (fun () -> test_rot ~cs "0" 0 Left "0")) ) ;
  ()

let%test_unit "bitwise shift gadgets" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test LSL and LSR gadgets
     *   Input operands and expected output: word len mode shifted
     *   Returns unit if constraints are satisfied, error otherwise.
     *)
    let test_shift ?cs word length mode result =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Set up snarky variables for inputs and output *)
            let word =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string word )
            in
            let result =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string result )
            in
            (* Use the xor gate gadget *)
            let output_shift =
              match mode with
              | Left ->
                  lsl64 (module Runner.Impl) word length
              | Right ->
                  lsr64 (module Runner.Impl) word length
            in
            Field.Assert.equal output_shift result )
      in
      cs
    in
    (* Positive tests *)
    let cs1l = test_shift "0" 1 Left "0" in
    let cs1r = test_shift "0" 1 Right "0" in
    let _cs = test_shift ~cs:cs1l "1" 1 Left "2" in
    let _cs = test_shift ~cs:cs1r "1" 1 Right "0" in
    let _cs = test_shift "256" 4 Right "16" in
    let _cs = test_shift "256" 20 Right "0" in
    let _cs = test_shift "6510615555426900570" 16 Right "99344109427290" in
    (* All 1's word *)
    let cs_allones =
      test_shift "18446744073709551615" 15 Left "18446744073709518848"
    in
    (* Random value ADCC7E30EDCAC126 -> ADCC7E30 -> EDCAC12600000000*)
    let _cs = test_shift "12523523412423524646" 32 Right "2915860016" in
    let _cs =
      test_shift "12523523412423524646" 32 Left "17134720101237391360"
    in

    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_shift "0" 1 Left "1")) ;
    assert (Common.is_error (fun () -> test_shift "1" 64 Left "1")) ;
    assert (Common.is_error (fun () -> test_shift ~cs:cs_allones "0" 0 Left "0"))
    ) ;
  ()

let%test_unit "bitwise xor gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test XOR gadget
     *   Inputs operands and expected output: left_input xor right_input
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_xor ?cs left_input right_input output_xor length =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Set up snarky variables for inputs and output *)
            let left_input =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) left_input )
            in
            let right_input =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) right_input )
            in
            let output_xor =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) output_xor )
            in
            (* Use the xor gate gadget *)
            let result =
              bxor (module Runner.Impl) left_input right_input length
            in

            (* Check that the result is equal to the expected output *)
            Field.Assert.equal output_xor result )
      in
      cs
    in

    (* Positive tests *)
    let cs16 = test_xor "1" "0" "1" 16 in
    let _cs = test_xor ~cs:cs16 "0" "1" "1" 16 in
    let _cs = test_xor ~cs:cs16 "2" "1" "3" 16 in
    let _cs = test_xor ~cs:cs16 "a8ca" "ddd5" "751f" 16 in
    let _cs = test_xor ~cs:cs16 "0" "0" "0" 8 in
    let _cs = test_xor ~cs:cs16 "0" "0" "0" 1 in
    let _cs = test_xor ~cs:cs16 "1" "0" "1" 1 in
    let _cs = test_xor ~cs:cs16 "0" "0" "0" 4 in
    let _cs = test_xor ~cs:cs16 "1" "1" "0" 4 in
    let cs32 = test_xor "bb5c6" "edded" "5682b" 20 in
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

    (* Negatve tests *)
    assert (
      Common.is_error (fun () ->
          (* Reusing right CS with bad witness *)
          test_xor ~cs:cs32 "ed1ed1" "ed1ed1" "010101" 20 ) ) ;
    assert (
      Common.is_error (fun () ->
          (* Reusing wrong CS with right witness *)
          test_xor ~cs:cs32 "1" "1" "0" 16 ) ) ;

    assert (Common.is_error (fun () -> test_xor ~cs:cs16 "1" "0" "1" 0)) ;
    assert (Common.is_error (fun () -> test_xor ~cs:cs16 "1" "0" "0" 1)) ;
    assert (Common.is_error (fun () -> test_xor ~cs:cs16 "1111" "2222" "0" 16)) ;
    assert (Common.is_error (fun () -> test_xor "0" "0" "0" 256)) ;
    assert (Common.is_error (fun () -> test_xor "0" "0" "0" (-4))) ;
    assert (
      Common.is_error (fun () -> test_xor ~cs:cs32 "bb5c6" "edded" "ed1ed1" 20) )
    ) ;
  ()

let%test_unit "bitwise and gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in
    (* Helper to test AND gadget
     *   Inputs operands and expected output: left_input and right_input = output
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_and ?cs left_input right_input output_and length =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Set up snarky variables for inputs and outputs *)
            let left_input =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) left_input )
            in
            let right_input =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) right_input )
            in
            let output_and =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) output_and )
            in
            (* Use the and gate gadget *)
            let result =
              band (module Runner.Impl) left_input right_input length
            in
            Field.Assert.equal output_and result )
      in
      cs
    in

    (* Positive tests *)
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
    let cs =
      test_and ~cs "385e243cb60654fd" "010fde9342c0d700" "e041002005400" 64
    in
    (* Negatve tests *)
    assert (
      Common.is_error (fun () ->
          (* Reusing right CS with wrong witness *) test_and ~cs "1" "1" "0" 20 ) ) ;
    assert (
      Common.is_error (fun () ->
          (* Reusing wrong CS with right witness *) test_and ~cs "1" "1" "1" 1 ) ) ;
    assert (Common.is_error (fun () -> test_and "1" "1" "0" 1)) ;
    assert (Common.is_error (fun () -> test_and "ff" "ff" "ff" 7)) ;
    assert (Common.is_error (fun () -> test_and "1" "1" "1" (-1))) ) ;
  ()

let%test_unit "bitwise not gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in
    (* Helper to test NOT gadget with both checked and unchecked length procedures
     *   Input and expected output and desired length : not(input) = output
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_not ?cs input output length =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Set up snarky variables for input and output *)
            let input =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) input )
            in

            let output =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) output )
            in

            (* Use the not gate gadget *)
            let result_checked =
              bnot_checked (module Runner.Impl) input length
            in
            let result_unchecked =
              bnot_unchecked (module Runner.Impl) input length
            in
            Field.Assert.equal output result_checked ;
            Field.Assert.equal output result_unchecked )
      in
      cs
    in

    (* Positive tests *)
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
    let _cs = test_not ~cs:cs64 "0" "ffffffffffffffff" 64 in
    let _cs =
      test_not
        "3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" "0"
        254
    in

    (* Negative tests *)
    assert (
      Common.is_error (fun () ->
          (* Reusing right CS with bad witness *)
          test_not ~cs:cs64 "0" "ff" 64 ) ) ;
    assert (
      Common.is_error (fun () ->
          (* Reusing wrong CS with right witness *)
          test_not ~cs:cs16 "1" "0" 1 ) ) ;
    assert (Common.is_error (fun () -> test_not "0" "0" 1)) ;
    assert (Common.is_error (fun () -> test_not "ff" "0" 4)) ;
    assert (
      Common.is_error (fun () ->
          test_not
            "7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
            "0" 255 ) ) ) ;
  ()
*)
