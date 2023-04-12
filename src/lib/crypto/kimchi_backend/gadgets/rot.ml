open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

(* ROT *)

(* Side of rotation *)
type direction = Left | Right

(* 64-bit rotation of rot_bits to the `direction` side *)
let bits64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (word : Circuit.Field.t) (rot_bits : int) (direction : direction) :
    Circuit.Field.t =
  let open Circuit in
  (* Check that the rotation bits is smaller than 64 *)
  assert (rot_bits < 64) ;
  (* Check that the rotation bits is non-negative *)
  assert (rot_bits >= 0) ;

  (* Compute actual length depending on whether the rotation direction is Left or Right *)
  let rot_bits =
    match direction with Left -> rot_bits | Right -> 64 - rot_bits
  in

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

  let of_bits =
    Common.as_prover_cvar_field_bits_le_to_cvar_field (module Circuit)
  in

  let rotated = values.(0) in
  let excess = values.(1) in
  let shifted = values.(2) in
  let bound = values.(3) in

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

let%test_unit "rot gadget" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test Rot gadget
     *   Input operands and expected output: word len direction rotated
     *   Returns unit if constraints are satisfied, error otherwise.
  *)
  let test_rot ?cs word length direction result =
    let cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof ?cs (fun () ->
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
          let output_rot = bits64 (module Runner.Impl) word length direction in
          Field.Assert.equal output_rot result ;
          (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
          Boolean.Assert.is_true (Field.equal output_rot output_rot) )
    in
    cs
  in

  (* Positive tests *)
  let _cs = test_rot "0" 0 Left "0" in
  let _cs = test_rot "0" 32 Right "0" in
  let _cs = test_rot "1" 1 Left "2" in
  let _cs = test_rot "1" 63 Left "9223372036854775808" in
  let cs = test_rot "256" 4 Right "16" in
  (* 0x5A5A5A5A5A5A5A5A is 0xA5A5A5A5A5A5A5A5 both when rotate 4 bits Left or Right*)
  let _cs = test_rot ~cs "6510615555426900570" 4 Right "11936128518282651045" in
  let _cs = test_rot "6510615555426900570" 4 Left "11936128518282651045" in
  let _cs = test_rot "1234567890" 32 Right "5302428712241725440" in

  (* Negatve tests *)
  assert (Common.is_error (fun () -> test_rot "0" 1 Left "1")) ;
  assert (Common.is_error (fun () -> test_rot "1" 64 Left "1")) ;
  ()
