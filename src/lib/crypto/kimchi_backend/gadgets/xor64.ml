open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* XOR *)

(* Xor of length bits *)
let xor (type f) 
(module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
(input1 : Circuit.Field.t) (input2 : Circuit.Field.t) (length : int): Circuit.Field.t =
let open Circuit in

   (* Convert to bits *)
   let input1_bits = Circuit.Field.unpack input1 in
   let input2_bits = Circuit.Field.unpack input2 in
 
   (* Check real lengths are at most the desired length *)
   assert (List.length input1_bits <= length) ;
   assert (List.length input2_bits <= length) ;
 
   (* Pad with zeros in MSB until reaching same length *)
 
   (* Witness computation; output = input1 xor input2 *)
   (* Xor list of bits to obtain output*)
     (* Witness computation; output = input1 xor input2 *)
  let output =
    exists Field.typ ~compute:(fun () ->
        let input1 = As_prover.read Field.typ input1 in
        let input2 = As_prover.read Field.typ input2 in
        Field.Constant.xor input1 input2 )
  in
   let output_bits = List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 ->
       Circuit.Boolean.(b1 lxor b2) ) in
 
   (* Convert back to field *)
   let output = Circuit.Field.project output_bits in

    xor_rec input1 input2 output length

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
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) (output : Circuit.Field.t) =
  let open Circuit in

  (* If inputs are zero, add the zero check *)
  if input1 = Field.zero && input2 = Field.zero then
    with_label "zero_check" (fun () ->
        assert_
          { annotation = Some __LOC__
          ; zero = Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
          (Basic
             { l = (Field.Constant.one, Field.Constant.zero)
             ; r = (Field.Constant.zero, Field.Constant.zero)
             ; o = (Option.value_exn Field.zero, Field.Constant.zero)
             ; m = Field.Constant.zero
             ; c = Field.Constant.one
             } )
          })
  else
  (* Nibbles *)
    let in1_nibbles = bits(input1, 0, 4);
    let in2_nibbles = bits(input2, 0, 4);
  
  with_label "xor16_gate" (fun () -> 
        (* Set up Xor gate *)
        assert_
          { annotation = Some __LOC__
          ; xor =
              Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                (Xor
                   { in1 = input1
                   ; in2 = input2
                   ; out = output
                   ; in1_0 = in1_nibbles.(0)
                   ; in1_1 = in1_nibbles.(1)
                   ; in1_2 = in1_nibbles.(2)
                   ; in1_3 = in1_nibbles.(3)
                   ; in2_0 = in2_nibbles.(0)
                   ; in2_1 = in2_nibbles.(1)
                   ; in2_2 = in2_nibbles.(2)
                   ; in2_3 = in2_nibbles.(3)
                   ; out_0 = out_nibbles.(0)
                   ; out_1 = out_nibbles.(1)
                   ; out_2 = out_nibbles.(2)
                   ; out_3 = out_nibbles.(3)
                   } )
          })
          let next_in1 = (input1 - in1_0  - in1_1 * 2^4 - in1_2 * 2^8 - in1_3 * 2^12) / 2^16;
          let next_in2 = (input2 - in2_0  - in2_1 * 2^4 - in2_2 * 2^8 - in2_3 * 2^12) / 2^16;
          let next_out = (output - out_0  - out_1 * 2^4 - out_2 * 2^8 - out_3 * 2^12) / 2^16;
          let next_length = length - 16 in
        (* Recursively call xor on the next nibble *)
        xor_rec (module Circuit) next_input1 next_input2 next_output new_length




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
            Field.Assert.equal sum result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true (Field.equal sum sum) )
      in
      true
    with _ -> false
  in

  (* Positive tests *)
  assert (Bool.equal (test_generic_add 0 0 0) true) ;
  assert (Bool.equal (test_generic_add 1 2 3) true) ;
  (* Negatve tests *)
  assert (Bool.equal (test_generic_add 1 0 0) false) ;
  assert (Bool.equal (test_generic_add 2 4 7) false) ;
  ()
