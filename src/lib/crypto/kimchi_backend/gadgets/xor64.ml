open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* XOR *)

(* Xor of length bits *)
let xor (type f) 
(module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
(input1 : Circuit.Field.t) (input2 : Circuit.Field.t) (length : int): Circuit.Field.t =
let open Circuit in

   (* Convert to bits *)
   let input1_bits = Circuit.Field.unpack @@ As_prover.read Field.typ input1 in
   let input2_bits = Circuit.Field.unpack @@ As_prover.read Field.typ input2 in
 
   (* Check real lengths are at most the desired length *)
   assert (List.length input1_bits <= length) ;
   assert (List.length input2_bits <= length) ;
 
   (* Pad with zeros in MSB until reaching same length *)
  for _ = List.length input1_bits to length do
    input1_bits <- input1_bits :: Circuit.Boolean.false_
  done
  for _ = List.length input2_bits to length do
    input2_bits <- input2_bits :: Circuit.Boolean.false_
  done

  (* Pad with more zeros until the length is a multiple of 16 *)
  let pad_length = length in
  while pad_length mod 16 != 0 do
    input1_bits <- input1_bits :: Circuit.Boolean.false_
    input2_bits <- input2_bits :: Circuit.Boolean.false_
    pad_length <- pad_length + 1
  done

   (* Xor list of bits to obtain output *)
   let output_bits = List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 ->
       b1 lxor b2 ) in

    (* Recursively build Xor gadget *) 
    xor_rec input1_bits input2_bits output_bits pad_length

  (* Transform output bits to field; output = input1 xor input2 *)
  let output = 
    exists Field.typ ~compute:(fun () ->
      As_prover.read Field.typ field_bits_le_to_field output_bits 0 length )
in

   (* Convert back to field *)
   let output = Circuit.Field.project output_bits in

    output

(* Xor of 16 bits *)
let xor16 
(module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
(input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
let open Circuit in
    xor input1 input2 16


(* Xor of 64 bits *)
let xor64 (type f)
(module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
(input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
let open Circuit in
    xor input1 input2 64

(* Recursively builds Xor *)
let rec xor_rec (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : List.Circuit.Boolean) (input2 : List.Circuit.Boolean) (output : Circuit.List.Boolean) (length: int) =
  let open Circuit in

  (* If inputs are zero and length is zero, add the zero check *)
  if length = 0 then
    assert (input1 = Field.zero) ;
    assert (input2 = Field.zero) ;
    assert (output = Field.zero) ;
    with_label "zero_check" (fun () ->
        assert_
          { annotation = Some __LOC__
          ; zero = Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
          (Basic
             { l = (Field.one, Field.Constant.zero)
             ; r = (Field.zero, Field.Constant.zero)
             ; o = (Option.value_exn Field.zero, Field.Constant.zero)
             ; m = Field.Constant.zero
             ; c = Field.Constant.one
             } )
          })
  else
  (* Nibbles *)
  let in1 = field_bits_le_to_field input1 0 length in
  let in2 = field_bits_le_to_field input2 0 length in
  let out = field_bits_le_to_field output 0 length in
  let in1_0 = field_bits_le_to_field input1 0 4 in
  let in1_1 = field_bits_le_to_field input1 4 8 in
  let in1_2 = field_bits_le_to_field input1 8 12 in
  let in1_3 = field_bits_le_to_field input1 12 16 in
  let in2_0 = field_bits_le_to_field input2 0 4 in
  let in2_1 = field_bits_le_to_field input2 4 8 in
  let in2_2 = field_bits_le_to_field input2 8 12 in
  let in2_3 = field_bits_le_to_field input2 12 16 in
  let out_0 = field_bits_le_to_field output 0 4 in
  let out_1 = field_bits_le_to_field output 4 8 in
  let out_2 = field_bits_le_to_field output 8 12 in
  let out_3 = field_bits_le_to_field output 12 16 in

  (* If length is more than 0, add the Xor gate *)
  with_label "xor16_gate" (fun () -> 
        (* Set up Xor gate *)
        assert_
          { annotation = Some __LOC__
          ; xor =
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
                   } )
          })
          (* Remove least significant 4 nibbles *)
          let next_in1 = remove in1_0 in1_1 in1_2 in1_3 from in1 in
          let next_in2 = (in2 - in2_0  - in2_1 * 2^4 - in2_2 * 2^8 - in2_3 * 2^12) / 2^16;
          let next_out = (out - out_0  - out_1 * 2^4 - out_2 * 2^8 - out_3 * 2^12) / 2^16;
          (* Next length is 4*4 less bits *)
          let next_length = length - 16 in

        (* Recursively call xor on the next nibble *)
        xor_rec (module Circuit) next_input1 next_input2 next_output next_length




let%test_unit "xor16 gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () = Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] in

  (* Helper to test xor16 gadget
   *   Inputs operands and expected output: left_input xor right_input
   *   Returns true if constraints are satisfied, false otherwise.
   *)
  let test_xor16 left_input right_input output =
    try
      let _proof_keypair, _proof =
        Runner.generate_and_verify_proof (fun () ->
            let open Runner.Impl in
            (* Set up snarky variables for inputs and outputs *)
            let left_input =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_int left_input )
            in
            let right_input =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_int right_input )
            in
            let output =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int output)
            in
            (* Use the xor16 gate gadget *)
            let result = xor16 (module Runner.Impl) left_input right_input in
            Field.Assert.equal output result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true (Field.equal Field.Constant.zero Field.Constant.zero) )
      in
      true
    with _ -> false
  in

  (* Positive tests *)
  assert (Bool.equal (test_xor16 0 0 0) true) ;
  assert (Bool.equal (test_xor16 43210 56789 29983) true) ;
  (* Negatve tests *)
  assert (Bool.equal (test_xor16 1 0 0) false) ;
  assert (Bool.equal (test_xor16 1111 2222 0) false) ;
  ()
