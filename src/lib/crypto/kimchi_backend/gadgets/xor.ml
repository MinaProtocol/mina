open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* XOR *)

(* Recursively builds Xor *)
let rec bxor_rec (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1_bits : bool list) (input2_bits : bool list)
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
                   { l = (Field.Constant.zero, Field.one)
                   ; r = (Field.Constant.zero, Field.zero)
                   ; o = (Option.value_exn Field.(to_constant zero), Field.zero)
                   ; m = Field.Constant.zero
                   ; c = Field.Constant.one
                   } )
          } ) )
  else
    (* Nibbles *)
    let in1 = Field.constant input1 in
    let in2 = Field.constant input2 in
    let out = Field.constant output in
    let in1_0 = Common.field_bits_le_to_field (module Circuit) in1 0 len_xor in
    let in1_1 =
      Common.field_bits_le_to_field
        (module Circuit)
        in1 len_xor
        Int.(2 * len_xor)
    in
    let in1_2 =
      Common.field_bits_le_to_field
        (module Circuit)
        in1
        Int.(2 * len_xor)
        Int.(3 * len_xor)
    in
    let in1_3 =
      Common.field_bits_le_to_field
        (module Circuit)
        in1
        Int.(3 * len_xor)
        Int.(4 * len_xor)
    in
    let in2_0 = Common.field_bits_le_to_field (module Circuit) in2 0 len_xor in
    let in2_1 =
      Common.field_bits_le_to_field
        (module Circuit)
        in2 len_xor
        Int.(2 * len_xor)
    in
    let in2_2 =
      Common.field_bits_le_to_field
        (module Circuit)
        in2
        Int.(2 * len_xor)
        Int.(3 * len_xor)
    in
    let in2_3 =
      Common.field_bits_le_to_field
        (module Circuit)
        in2
        Int.(3 * len_xor)
        Int.(4 * len_xor)
    in
    let out_0 = Common.field_bits_le_to_field (module Circuit) out 0 len_xor in
    let out_1 =
      Common.field_bits_le_to_field
        (module Circuit)
        out len_xor
        Int.(2 * len_xor)
    in
    let out_2 =
      Common.field_bits_le_to_field
        (module Circuit)
        out
        Int.(2 * len_xor)
        Int.(3 * len_xor)
    in
    let out_3 =
      Common.field_bits_le_to_field
        (module Circuit)
        out
        Int.(3 * len_xor)
        Int.(4 * len_xor)
    in

    (* If length is more than 0, add the Xor gate *)
    with_label "xor16_gate" (fun () ->
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
                   } )
          } ) ;

    (* Remove least significant 4 nibbles *)
    let next_in1 = List.drop input1_bits (4 * len_xor) in
    let next_in2 = List.drop input2_bits (4 * len_xor) in
    let next_out = List.drop output_bits (4 * len_xor) in
    (* Next length is 4*n less bits *)
    let next_length = length - (4 * len_xor) in

    (* Recursively call xor on the next nibble *)
    bxor_rec (module Circuit) next_in1 next_in2 next_out next_length len_xor ;
    ()

(* Boolean Xor of length bits *)
let bxor (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) (length : int)
    (len_xor : int) : Circuit.Field.t =
  let open Circuit in
  (* Check that the length is permitted *)
  assert (length < Field.size_in_bits) ;

  let output_xor =
    exists Field.typ ~compute:(fun () ->
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

        (* Xor list of bits to obtain output of the xor *)
        let output_bits =
          List.map2_exn input1_bits input2_bits ~f:(fun b1 b2 ->
              Bool.(not (equal b1 b2)) )
        in

        (* Recursively build Xor gadget *)
        bxor_rec
          (module Circuit)
          input1_bits input2_bits output_bits pad_length len_xor ;
        (* Convert back to field *)
        Field.Constant.project output_bits )
  in
  output_xor

(* Xor of 16 bits *)
let bxor16 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  let open Circuit in
  bxor (module Circuit) input1 input2 16 4

(* Xor of 64 bits *)
let bxor64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (input1 : Circuit.Field.t) (input2 : Circuit.Field.t) : Circuit.Field.t =
  let open Circuit in
  bxor (module Circuit) input1 input2 64 4

let%test_unit "xor gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () = Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] in

  (* Helper to test Xor gadget
     *   Inputs operands and expected output: left_input xor right_input
     *   Returns true if constraints are satisfied, false otherwise.
  *)
  let test_xor left_input right_input output_xor length =
    try
      let _proof_keypair, _proof =
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
              bxor (module Runner.Impl) left_input right_input length 4
            in
            Field.Assert.equal output_xor result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true (Field.equal result result) )
      in
      true
    with _ -> false
  in

  (* Positive tests *)
  assert (Bool.equal (test_xor "0" "0" "0" 16) true) ;
  assert (Bool.equal (test_xor "0" "0" "1" 8) true) ;
  assert (Bool.equal (test_xor "0" "0" "0" 1) true) ;
  assert (Bool.equal (test_xor "0" "0" "0" 4) true) ;
  assert (Bool.equal (test_xor "43210" "56789" "29983" 16) true) ;
  assert (Bool.equal (test_xor "767430" "974317" "354347" 20) true) ;
  (* 0x5A5A5A5A5A5A5A5A xor 0xA5A5A5A5A5A5A5A5 = 0xFFFFFFFFFFFFFFFF*)
  assert (
    Bool.equal
      (test_xor "6510615555426900570" "18446744073709551615" "72057594037927935"
         64 )
      true ) ;
  (* Negatve tests *)
  assert (Bool.equal (test_xor "1" "0" "0" 1) false) ;
  assert (Bool.equal (test_xor "1111" "2222" "0" 16) false) ;

  ()
