open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* AND *)

(* Boolean And of length bits *)
let band (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) (length : int)
    (len_xor : int) : Circuit.Field.t =
  let open Circuit in
  let output_and =
    exists Field.typ ~compute:(fun () ->
        (* Recursively build And gadget with leading Xors and a final Generic gate *)
        (* It will also check the right lengths of the inputs, no need to do it again *)
        let xor_output =
          Xor.bxor (module Circuit) input1 input2 length len_xor
        in

        (* Read inputs *)
        let input1_field =
          Common.cvar_field_to_field_as_prover (module Circuit) input1
        in
        let input2_field =
          Common.cvar_field_to_field_as_prover (module Circuit) input2
        in

        (* Convert inputs field elements to list of bits of length the field size *)
        let input1_bits = Field.Constant.unpack @@ input1_field in
        let input2_bits = Field.Constant.unpack @@ input2_field in

        (* AND list of bits to obtain output *)
        let and_bits =
          List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 -> b1 && b2)
        in

        (* Convert back to field a AND b *)
        let and_output = Field.Constant.project and_bits in

        (* Compute sum of a + b *)
        let sum = Field.add input1 input2 in

        with_label "sum_of_inputs" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (Basic
                       { force = Field.Constant.zero
                       ; l = (Field.Constant.one, input1)
                       ; r = (Field.Constant.one, input2)
                       ; o =
                           ( Option.value_exn Field.(to_constant (negate one))
                           , sum )
                       ; m = Field.Constant.zero
                       ; c = Field.Constant.zero
                       } )
              } ) ;

        (* Compute AND as 2 * and = sum - xor *)
        with_label "and_equation" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (Basic
                       { force = Field.Constant.zero
                       ; l = (Field.Constant.one, sum)
                       ; r =
                           ( Option.value_exn Field.(to_constant (negate one))
                           , xor_output )
                       ; o =
                           ( Option.value_exn
                               Field.(to_constant (negate @@ of_int 2))
                           , Common.field_to_cvar_field
                               (module Circuit)
                               and_output )
                       ; m = Field.Constant.zero
                       ; c = Field.Constant.zero
                       } )
              } ) ;
        and_output )
  in
  output_and

(* And of 64 bits *)
let band64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  band (module Circuit) input1 input2 64 4

let%test_unit "and gadget" =
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
    let _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          (* Set up snarky variables for inputs and outputs *)
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
          let output_and =
            Common.as_prover_cvar_field_of_base10
              (module Runner.Impl)
              output_and
          in
          (* Use the and gate gadget *)
          let result =
            band (module Runner.Impl) left_input right_input length 4
          in
          Field.Assert.equal output_and result ;
          (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
          Boolean.Assert.is_true (Field.equal result result) )
    in
    ()
  in

  let test_2and left1 right1 output1 left2 right2 output2 length : unit =
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
          let result1 = band (module Runner.Impl) left1 right1 length 4 in
          let result2 = band (module Runner.Impl) left2 right2 length 4 in
          Field.Assert.equal output1 result1 ;
          Field.Assert.equal output2 result2 ;
          Boolean.Assert.is_true (Field.equal result1 result1) )
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
  test_2and "1111" "2222" "6" "43210" "56789" "35008" 16 ;
  (* Negatve tests *)
  assert (Common.is_error (fun () -> test_and "1" "1" "0" 1)) ;
  assert (Common.is_error (fun () -> test_and "255" "255" "255" 7)) ;
  ()
