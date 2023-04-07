open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

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
  let and_output =
    exists Field.typ ~compute:(fun () ->
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
        Field.Constant.project and_bits )
  in

  (* Recursively build And gadget with leading Xors and a final Generic gate *)
  (* It will also check the right lengths of the inputs, no need to do it again *)
  let xor_output = Xor.bxor (module Circuit) input1 input2 length ~len_xor in
  (* Transform to non constant cvar *)
  let xor_output_var =
    exists Field.typ ~compute:(fun () ->
        Common.cvar_field_to_field_as_prover (module Circuit) xor_output )
  in

  (* Compute sum of a + b and constrain in the circuit *)
  let sum = Generic.add (module Circuit) input1 input2 in
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

(* And of 64 bits
   * input1 and input2 are the two inputs to AND
*)
let band64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  band (module Circuit) input1 input2 64

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
  ()
