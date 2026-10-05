open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Circuit = Kimchi_pasta_snarky_backend.Step_impl

(** Returns a field containing the all one word of length bits. *)
let all_ones_field (length : int) =
  Common.bignum_bigint_to_field
  @@ Bignum_bigint.(pow (of_int 2) (of_int length) - one)

let fits_in_bits_as_prover (word : Circuit.Field.t) (length : int) =
  let open Common in
  assert (
    Bignum_bigint.(
      field_to_bignum_bigint (cvar_field_to_field_as_prover word)
      < pow (of_int 2) (of_int length)) )

(** Side of rotation. *)
type rot_mode = Left | Right

(** Performs the 64-bit rotation and returns rotated word, excess, and
    shifted. *)
let rot_aux ?(check64 = false) (word : Circuit.Field.t) (bits : int)
    (mode : rot_mode) : Circuit.Field.t * Circuit.Field.t * Circuit.Field.t =
  let open Circuit in
  (* Check that the rotation bits is smaller than 64 *)
  assert (bits < 64) ;
  (* Check that the rotation bits is non-negative *)
  assert (bits >= 0) ;

  (* Check that the input word has at most 64 bits *)
  as_prover (fun () ->
      fits_in_bits_as_prover word 64 ;
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
          Common.(field_to_bignum_bigint (cvar_field_to_field_as_prover word))
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
        let shifted = Common.bignum_bigint_to_field shifted_big in
        let excess = Common.bignum_bigint_to_field excess_big in
        let rotated = Common.bignum_bigint_to_field rotated_big in
        let bound = Common.bignum_bigint_to_field bound_big in

        [| rotated; excess; shifted; bound |] )
    |> Common.tuple4_of_array
  in

  let of_bits = Common.as_prover_cvar_field_bits_le_to_cvar_field in

  (* Current row *)
  with_label "rot64_gate" (fun () ->
      (* Set up Rot64 gate *)
      assert_
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
           ; two_to_rot = Common.bignum_bigint_to_field big_2_pow_rot
           } ) ) ;

  (* Next row *)
  Range_check.bits64 shifted ;

  (* Following row *)
  Range_check.bits64 excess ;

  if check64 then Range_check.bits64 word ;

  (rotated, excess, shifted)

(** 64-bit rotation of [rot_bits] to the [mode] side.

    @param check64 whether to check the input word is at most 64 bits
                   (default is false)
    @param word word of maximum 64 bits to be rotated
    @param rot_bits number of bits to be rotated
    @param mode Left or Right
    @return rotated word *)
let rot64 ?(check64 : bool = false) (word : Circuit.Field.t) (rot_bits : int)
    (mode : rot_mode) : Circuit.Field.t =
  let rotated, _excess, _shifted = rot_aux ~check64 word rot_bits mode in

  rotated

(** 64-bit bitwise logical shift of bits to the left side.

    @param check64 whether to check the input word is at most 64 bits
                   (default is false)
    @param word word of maximum 64 bits to be shifted
    @param bits number of bits to be shifted
    @return left shifted word (with 0s at the least significant positions) *)
let lsl64 ?(check64 : bool = false) (word : Circuit.Field.t) (bits : int) :
    Circuit.Field.t =
  let _rotated, _excess, shifted = rot_aux ~check64 word bits Left in

  shifted

(** 64-bit bitwise logical shift of bits to the right side.

    @param check64 whether to check the input word is at most 64 bits
                   (default is false)
    @param word word of maximum 64 bits to be shifted
    @param bits number of bits to be shifted
    @return right shifted word (with 0s at the most significant positions) *)
let lsr64 ?(check64 : bool = false) (word : Circuit.Field.t) (bits : int) :
    Circuit.Field.t =
  let _rotated, excess, _shifted = rot_aux ~check64 word bits Right in

  excess

(** Boolean XOR of [length] bits.

    @param len_xor number of bits of the lookup table (default is 4)
    @param input1 first input to the XOR gate
    @param input2 second input to the XOR gate
    @param length number of bits to XOR
    @return XOR of input1 and input2 *)
let bxor ?(len_xor = 4) (input1 : Circuit.Field.t) (input2 : Circuit.Field.t)
    (length : int) : Circuit.Field.t =
  (* Auxiliar function to compute the next variable for the chain of Xors *)
  let as_prover_next_var (curr_var : Circuit.Field.t) (var0 : Circuit.Field.t)
      (var1 : Circuit.Field.t) (var2 : Circuit.Field.t) (var3 : Circuit.Field.t)
      (len_xor : int) : Circuit.Field.t =
    let open Circuit in
    let two_pow_len =
      Common.bignum_bigint_to_field
        Bignum_bigint.(pow (of_int 2) (of_int len_xor))
    in
    let two_pow_2len = Field.Constant.(two_pow_len * two_pow_len) in
    let two_pow_3len = Field.Constant.(two_pow_2len * two_pow_len) in
    let two_pow_4len = Field.Constant.(two_pow_3len * two_pow_len) in
    let next_var =
      exists Field.typ ~compute:(fun () ->
          let curr_field = Common.cvar_field_to_field_as_prover curr_var in
          let field0 = Common.cvar_field_to_field_as_prover var0 in
          let field1 = Common.cvar_field_to_field_as_prover var1 in
          let field2 = Common.cvar_field_to_field_as_prover var2 in
          let field3 = Common.cvar_field_to_field_as_prover var3 in
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
            (Raw { kind = Zero; values = [| in1; in2; out |]; coeffs = [||] }) ) ;
      Field.Assert.equal Field.zero in1 ;
      Field.Assert.equal Field.zero in2 ;
      Field.Assert.equal Field.zero out ;
      () )
    else
      (* Define shorthand helper *)
      let of_bits = Common.as_prover_cvar_field_bits_le_to_cvar_field in

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

      (* If length is more than 0, add the Xor gate *)
      with_label "xor_gate" (fun () ->
          (* Set up Xor gate *)
          assert_
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
               } ) ) ;

      let next_in1 = as_prover_next_var in1 in1_0 in1_1 in1_2 in1_3 len_xor in
      let next_in2 = as_prover_next_var in2 in2_0 in2_1 in2_2 in2_3 len_xor in
      let next_out = as_prover_next_var out out_0 out_1 out_2 out_3 len_xor in

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
      let input1_field = cvar_field_to_field_as_prover input1 in
      let input2_field = cvar_field_to_field_as_prover input2 in

      (* Check real lengths are at most the desired length *)
      fits_in_bits_as_prover input1 length ;
      fits_in_bits_as_prover input2 length ;

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
        fits_in_bits_as_prover input1 length ;
        fits_in_bits_as_prover input2 length ;

        let input1_field = cvar_field_to_field_as_prover input1 in
        let input2_field = cvar_field_to_field_as_prover input2 in

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

(** Boolean XOR of 16 bits. This is a special case of XOR for 16 bits using a
    4-bit lookup table. Receives two input words of maximum 16 bits each.
    Returns the XOR of the two words. *)
let bxor16 (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) :
    Circuit.Field.t =
  bxor input1 input2 16 ~len_xor:4

(** Boolean XOR of 64 bits. This is a special case of XOR for 64 bits using a
    4-bit lookup table. Receives two input words of maximum 64 bits each.
    Returns the XOR of the two words. *)
let bxor64 (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) :
    Circuit.Field.t =
  bxor input1 input2 64 ~len_xor:4

(** Boolean AND of [length] bits.

    @param len_xor number of bits of the XOR lookup table (default is 4)
    @param input1 first input to AND
    @param input2 second input to AND
    @param length number of bits to AND
    @return AND of input1 and input2 *)
let band ?(len_xor = 4) (input1 : Circuit.Field.t) (input2 : Circuit.Field.t)
    (length : int) : Circuit.Field.t =
  let open Circuit in
  (* Recursively build And gadget with leading Xors and a final Generic gate *)
  (* It will also check the correct lengths of the inputs, no need to do it again *)
  let xor_output = bxor input1 input2 length ~len_xor in

  let and_output =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_bits_combine_as_prover input1 input2 (fun b1 b2 ->
            b1 && b2 ) )
  in

  (* Compute sum of a + b and constrain in the circuit *)
  let sum = Generic.add input1 input2 in
  let neg_one = Field.Constant.(negate one) in
  let neg_two = Field.Constant.(neg_one + neg_one) in

  (* Constrain AND as 2 * and = sum - xor *)
  with_label "and_equation" (fun () ->
      assert_
        (Basic
           { l = (Field.Constant.one, sum)
           ; r = (neg_one, xor_output)
           ; o = (neg_two, and_output)
           ; m = Field.Constant.zero
           ; c = Field.Constant.zero
           } ) ) ;

  and_output

(** Boolean AND of 64 bits. This is a special case of AND for 64 bits using a
    4-bit XOR lookup table. Receives two input words of maximum 64 bits each.
    Returns the AND of the two words. *)
let band64 (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) :
    Circuit.Field.t =
  band input1 input2 64

(** Boolean NOT of [length] bits with checked length (uses XOR gadgets inside
    to constrain the length).

    Note: the length must be less than the bit length of the field.

    @param len_xor length of the XOR lookup table to use (default 4)
    @param input word to negate
    @param length number of bits
    @return negated word *)
let bnot_checked ?(len_xor = 4) (input : Circuit.Field.t) (length : int) :
    Circuit.Field.t =
  let open Circuit in
  (* Check it is not 255 or else 2^255-1 will not fit in Pallas *)
  assert (length < Circuit.Field.size_in_bits) ;

  let all_ones_f = all_ones_field length in
  let all_ones_var = exists Field.typ ~compute:(fun () -> all_ones_f) in

  (* Negating is equivalent to XORing with all one word *)
  let out_not = bxor input all_ones_var length ~len_xor in

  (* Doing this afterwards or else it can break chainability with Xor16's and Zero *)
  Field.Assert.equal (Field.constant all_ones_f) all_ones_var ;

  out_not

(** Negates a word of 64 bits with checked length of 64 bits. This means that
    the bound in length is constrained in the circuit. *)
let bnot64_checked (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_checked input 64

(** Boolean NOT of [length] bits with unchecked length (uses Generic
    subtractions inside).

    Note: this can negate two words per row, but inputs need to be a copy of
    another variable with a correct length in order to ensure the length is
    correct.

    @param input word to negate
    @param length number of bits
    @return negated word *)
let bnot_unchecked (input : Circuit.Field.t) (length : int) : Circuit.Field.t =
  let open Circuit in
  (* Check it is not 255 or else 2^255-1 will not fit in Pallas *)
  assert (length < Circuit.Field.size_in_bits) ;
  assert (length > 0) ;

  (* Check that the input word has at most length bits.
     In the checked version this is done in the Xor *)
  as_prover (fun () ->
      fits_in_bits_as_prover input length ;
      () ) ;

  let all_ones_f = all_ones_field length in
  let all_ones_var = exists Field.typ ~compute:(fun () -> all_ones_f) in
  Field.Assert.equal all_ones_var (Field.constant all_ones_f) ;

  (* Negating is equivalent to subtracting with all one word *)
  (* [2^len - 1] - input = not (input) *)
  Generic.sub all_ones_var input

(** Negates a word of 64 bits, but its length goes unconstrained in the circuit
    (unless it is copied from a checked length value). *)
let bnot64_unchecked (input : Circuit.Field.t) : Circuit.Field.t =
  bnot_unchecked input 64
