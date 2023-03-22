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
        let xor_output = Xor.bxor input1 input2 length len_xor in

        (* Read inputs *)
        let input1_field = As_prover.read Field.typ input1 in
        let input2_field = As_prover.read Field.typ input2 in

        (* Convert inputs field elements to list of bits *)
        let input1_bits = Field.Constant.unpack @@ input1_field in
        let input2_bits = Field.Constant.unpack @@ input2_field in

        (* Check real lengths are at most the desired length *)
        assert (List.length input1_bits <= length) ;
        assert (List.length input2_bits <= length) ;

        (* Pad with zeros in MSB until reaching same length *)
        let input1_bits = Common.pad_upto ~length ~value:false input1_bits in
        let input2_bits = Common.pad_upto ~length ~value:false input2_bits in

        (* Pad with more zeros until the length is a multiple of 4*n for n-bit length lookup table *)
        let pad_length =
          if length mod 4 * len_xor <> 0 then
            length + ((4 * len_xor) - (length mod 4 * len_xor))
          else length
        in
        let input1_bits =
          Common.pad_upto ~length:pad_length ~value:false input1_bits
        in
        let input2_bits =
          Common.pad_upto ~length:pad_length ~value:false input2_bits
        in

        (* AND list of bits to obtain output *)
        let and_bits =
          List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 -> b1 && b2)
        in

        (* Convert back to field a AND b *)
        let and_output =
          exists Field.typ ~compute:(fun () -> Field.Constant.project and_bits)
        in

        (* Compute sum of a + b *)
        let sum = Field.add input1 input2 in

        with_label "sum_of_inputs" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (Basic
                       { l = (Field.Constant.one, input1)
                       ; r = (Field.Constant.one, input2)
                       ; o =
                           ( Option.value_exn Field.(to_constant (negate one))
                           , sum )
                       ; m = Field.Constant.zero
                       ; c = Field.Constant.zero
                       } )
              } ) ;

        (* Compute AND as 2 * and = sum - xor *)
        let two = Field.Constant.of_int 2 in
        with_label "and_equation" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (Basic
                       { l = (Field.Constant.one, sum)
                       ; r =
                           ( Field.Constant.(to_constant (negate one))
                           , xor_output )
                       ; o =
                           ( Option.value_exn Field.(to_constant (negate two))
                           , Field.and_output )
                       ; m = Field.Constant.zero
                       ; c = Field.Constant.zero
                       } )
              } ) ;
        and_output )
  in
  output_and ()
(*
(* And of 64 bits *)
let band64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  let open Circuit in
  band input1 input2 64

let%test_unit "and gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () = Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] in

  (* Helper to test And gadget
     *   Inputs operands and expected output: left_input and right_input = output
     *   Returns true if constraints are satisfied, false otherwise.
  *)
  let test_and left_input right_input output length =
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
            (* Use the and gate gadget *)
            let result =
              band (module Runner.Impl) left_input right_input length
            in
            Field.Assert.equal output result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true
              (Field.equal Field.Constant.zero Field.Constant.zero) )
      in
      true
    with _ -> false
  in

  (* Positive tests *)
  let zero = Field.zero in
  let one = Field.one in
  assert (Bool.equal (test_and zero zero zero 16) true) ;
  assert (Bool.equal (test_and zero one zero 8) true) ;
  assert (Bool.equal (test_and one one one 1) true) ;
  assert (Bool.equal (test_and Field.of_int 15 Field.of_int 15 zero 4) true) ;
  assert (Bool.equal (test_and 1111 2222 6 16) true) ;
  assert (
    Bool.equal
      (test_and Field.of_int 43210 Field.of_int 56789 Field.of_int 35008 16)
      true ) ;
  assert (
    Bool.equal
      (test_and Field.of_int 767430 Field.of_int 974317 Field.of_int 693700 20)
      true ) ;
  (* 0x5A5A5A5A5A5A5A5A and 0xA5A5A5A5A5A5A5A5 = 0x0000000000000000*)
  assert (
    Bool.equal
      (test_and Common.field_from_base10 "6510615555426900570"
         Common.field_from_base10 "18446744073709551615" zero 64 )
      true ) ;
  (* Negatve tests *)
  assert (Bool.equal (test_and 1 1 0 1) false) ;
  ()
*)
