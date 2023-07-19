open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let tests_enabled = true

(* Array to tuple helper *)
let tuple6_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6 |] ->
      (a1, a2, a3, a4, a5, a6)
  | _ ->
      assert false

(* Gadget to assert signature scalars r,s \in Fn
 * Must be used when r and s are not public parameters
 *
 *   Scalar field external checks:
 *     Bound checks:         6
 *     Multi-range-checks:   2
 *     Compact-range-checks: 2
 *     Total range-checks:   10
 *
 *   Rows: (per crumb, not counting inputs/outputs and constants)
 *     Check:               4
 *     Bound additions:    12
 *     Multi-range-checks: 40
 *     Total:              56
 *)
let signature_scalar_check (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (scalar_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t)
    (signature :
      f Foreign_field.Element.Standard.t * f Foreign_field.Element.Standard.t )
    =
  let open Circuit in
  (* Signaure r and s *)
  let r, s = signature in

  (* Compute witness r^-1 and s^-1 needed for not-zero-check *)
  let r_inv0, r_inv1, r_inv2, s_inv0, s_inv1, s_inv2 =
    exists (Typ.array ~length:6 Field.typ) ~compute:(fun () ->
        let curve_order =
          Foreign_field.field_const_standard_limbs_to_bignum_bigint
            (module Circuit)
            curve.order
        in

        let r =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            r
        in

        let s =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            s
        in

        (* Compute r^-1 *)
        let r_inv = Common.bignum_bigint_inverse r curve_order in

        (* Compute s^-1 *)
        let s_inv = Common.bignum_bigint_inverse s curve_order in

        (* Convert from Bignums to field elements *)
        let r_inv0, r_inv1, r_inv2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            r_inv
        in
        let s_inv0, s_inv1, s_inv2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            s_inv
        in

        (* Return and convert back to Cvars *)
        [| r_inv0; r_inv1; r_inv2; s_inv0; s_inv1; s_inv2 |] )
    |> tuple6_of_array
  in
  let r_inv =
    Foreign_field.Element.Standard.of_limbs (r_inv0, r_inv1, r_inv2)
  in
  let s_inv =
    Foreign_field.Element.Standard.of_limbs (s_inv0, s_inv1, s_inv2)
  in

  let one = Foreign_field.Element.Standard.one (module Circuit) in

  (* C1: Constrain that r != 0 *)
  let computed_one =
    Foreign_field.mul (module Circuit) scalar_checks r r_inv curve.order
  in
  (* Bounds 1: Left input r is bound checked below
   *           Right input r_inv is bound checked below
   *           Result bound check is covered by scalar_checks
   *)
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs r ;
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs r_inv ;
  (* Assert r * r^-1 = 1 *)
  Foreign_field.Element.Standard.assert_equal (module Circuit) computed_one one ;

  (* C2: Constrain that s != 0 *)
  let computed_one =
    Foreign_field.mul (module Circuit) scalar_checks s s_inv curve.order
  in
  (* Bounds 2: Left input s is bound checked below
   *           Right input s_inv is bound checked below
   *           Result bound check is covered by scalar_checks
   *)
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs s ;
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs s_inv ;
  (* Assert s * s^-1 = 1 *)
  Foreign_field.Element.Standard.assert_equal (module Circuit) computed_one one

(* C3: Assert r \in [0, n)
 *     Already covered by bound check on r (Bounds 1)
 *)
(* C4: Assert s \in [0, n)
 *     Already covered by bound check on s (Bounds 2)
 *)

(* Gadget for constraining ECDSA signature verificationin zero-knowledge
 *
 *   Inputs:
 *     base_checks           := Context to track required base field external checks
 *     scalar_checks         := Context to track required scalar field external checks
 *     curve                 := Elliptic curve parameters
 *     pubkey                := Public key of signer
 *     doubles               := Optional powers of 2^i * pubkey, 0 <= i < n where n is curve.order_bit_length
 *     signature             := ECDSA signature (r, s) s.t. r, s \in [1, n)
 *     msg_hash              := Message hash s.t. msg_hash \in Fn
 *
 *   Preconditions:
 *      pubkey is on the curve and not O   (use Ec_group.is_on_curve gadget)
 *      pubkey is in the subgroup (nP = O) (use Ec_group.check_subgroup gadget)
 *      pubkey is bounds checked           (use multi-range-check gadgets)
 *      r, s \in [1, n)                    (use signature_scalar_check gadget)
 *      msg_hash \in Fn                    (use bytes_to_foreign_field_element gadget)
 *
 *   Public parameters
 *      gen is the correct elliptic curve group generator point
 *      a, b are correct elliptic curve parameters
 *      curve order is the correct elliptic curve group order
 *      curve modulus is the correct elliptic curve base field modulus
 *      ia point is publically, deterministically and randomly selected (nothing-up-my-sleeve)
 *      ia on the curve
 *      ia negated point computation is correct
 *      ia coordinates are valid
 *
 *   Base field external checks: (per crumb, not counting inputs and output)
 *     Bound checks:         100 (+2 when a != 0 and +1 when b != 0)
 *     Multi-range-checks:    40
 *     Compact-range-checks:  40
 *     Total range-checks:   180
 *
 *   Scalar field external checks: (per crumb, not counting inputs and output)
 *     Bound checks:          5
 *     Multi-range-checks:    3
 *     Compact-range-checks:  3
 *     Total range-checks:   11
 *
 *   Rows: (per crumb, not counting inputs/outputs and constants)
 *     Verify:              ~205 (+5 when a != 0 and +2 when b != 0)
 *     Bound additions:      210
 *     Multi-range-checks:   764
 *     Total:               1179
 *
 *   Constants:
 *     Curve constants:        10 (for 256-bit curve; one-time cost per circuit)
 *     Pre-computing doubles: 767 (for 256-bit curve; one-time cost per circuit)
 *
 *)
let verify (type f) (module Circuit : Snark_intf.Run with type field = f)
    (base_checks : f Foreign_field.External_checks.t)
    (scalar_checks : f Foreign_field.External_checks.t)
    (curve : f Curve_params.InCircuit.t) (pubkey : f Affine.t)
    ?(use_precomputed_gen_doubles = true) ?(scalar_mul_bit_length = 0)
    ?(doubles : f Affine.t array option)
    (signature :
      f Foreign_field.Element.Standard.t * f Foreign_field.Element.Standard.t )
    (msg_hash : f Foreign_field.Element.Standard.t) =
  let open Circuit in
  (* Signaures r and s *)
  let r, s = signature in

  (* Compute witness value u1 and u2 *)
  let u1_0, u1_1, u1_2, u2_0, u2_1, u2_2 =
    exists (Typ.array ~length:6 Field.typ) ~compute:(fun () ->
        let r =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            r
        in

        let s =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            s
        in

        let msg_hash =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            msg_hash
        in

        (* Compute s^-1 *)
        let s_inv = Common.bignum_bigint_inverse s curve.bignum.order in

        (* Compute u1 = z * s^-1 *)
        let u1 = Bignum_bigint.(msg_hash * s_inv % curve.bignum.order) in

        (* Compute u2 = r * s^-1 *)
        let u2 = Bignum_bigint.(r * s_inv % curve.bignum.order) in

        (* Convert from Bignums to field elements *)
        let u1_0, u1_1, u1_2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            u1
        in
        let u2_0, u2_1, u2_2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            u2
        in

        (* Return and convert back to Cvars *)
        [| u1_0; u1_1; u1_2; u2_0; u2_1; u2_2 |] )
    |> tuple6_of_array
  in
  let u1 = Foreign_field.Element.Standard.of_limbs (u1_0, u1_1, u1_2) in
  let u2 = Foreign_field.Element.Standard.of_limbs (u2_0, u2_1, u2_2) in

  (* C1: Constrain s * u1 = z *)
  let msg_hash_computed =
    Foreign_field.mul
      (module Circuit)
      scalar_checks ~bound_check_result:false s u1 curve.order
  in
  (* Bounds 1: Left input s is gadget input (checked externally)
   *           Right input u1 checked below
   *           Result is gadget input (already checked externally).
   *)
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs u1 ;

  (* Assert s * u1 = z *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    msg_hash_computed msg_hash ;

  (* C2: Constrain s * u2 = r *)
  let r_computed =
    Foreign_field.mul
      (module Circuit)
      scalar_checks ~bound_check_result:false s u2 curve.order
  in

  (* Bounds 2: Left input s is gadget input (checked externally)
   *           Right input u2 checked below
   *           Result is gadget input (already checked externally).
   *)
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs u2 ;

  (* Assert s * u2 = r *)
  Foreign_field.Element.Standard.assert_equal (module Circuit) r_computed r ;

  (*
   * Compute R = u1G + u2P
   *)

  (* Set optional alternative scalar_mul_bit_length *)
  let scalar_bit_length =
    if scalar_mul_bit_length > 0 then scalar_mul_bit_length
    else curve.order_bit_length
  in

  (* C3: Decompose u1 into bits *)
  let u1_bits =
    Foreign_field.Element.Standard.unpack
      (module Circuit)
      u1 ~length:scalar_bit_length
  in

  (* C4: Decompose u2 into bits *)
  let u2_bits =
    Foreign_field.Element.Standard.unpack
      (module Circuit)
      u2 ~length:scalar_bit_length
  in

  (* C5: Constrain scalar multiplication u1G *)
  let curve_doubles =
    if use_precomputed_gen_doubles then Some curve.doubles else None
  in
  let u1_point =
    Ec_group.scalar_mul
      (module Circuit)
      base_checks curve ?doubles:curve_doubles u1_bits curve.gen
  in

  (* Bounds 5: Generator is gadget input (public parameter)
   *           Initial accumulator is gadget input (checked externally or public parameter)
   *           Result bound check for u1_point below.
   *)
  Foreign_field.External_checks.append_bound_check base_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x u1_point ;
  Foreign_field.External_checks.append_bound_check base_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y u1_point ;

  (* C6: Constrain scalar multiplication u2P *)
  let u2_point =
    Ec_group.scalar_mul
      (module Circuit)
      base_checks curve ?doubles u2_bits pubkey
  in

  (* Bounds 6: Pubkey is gadget input (checked externally)
   *           Initial accumulator is gadget input (checked externally or public parameter)
   *           Result bound check for u2_point below.
   *)
  Foreign_field.External_checks.append_bound_check base_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x u2_point ;
  Foreign_field.External_checks.append_bound_check base_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y u2_point ;

  (* C7: R = u1G + u2P *)
  let result =
    Ec_group.add (module Circuit) base_checks curve u1_point u2_point
  in

  (* Bounds 7: Left and right inputs checked by (Bounds 5) and (Bounds 6)
   *           Result bound is bound checked below
   *)
  Foreign_field.External_checks.append_bound_check base_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.x result ;
  Foreign_field.External_checks.append_bound_check base_checks
  @@ Foreign_field.Element.Standard.to_limbs @@ Affine.y result ;

  (* Constrain that r = Rx (mod n), where n is the scalar field modulus
   *
   *   Note: The scalar field modulus (curve.order) may be greater or smaller than
   *         the base field modulus (curve.modulus)
   *
   *           curve.order > curve.modulus => Rx = 0 * n + Rx
   *
   *           curve.order < curve.modulus  => Rx = q * n + Rx'
   *
   *  Thus, to check for congruence we need to compute the modular reduction of Rx and
   *  assert that it equals r.
   *
   *  Since we may want to target applications where the scalar field is much smaller
   *  than the base field, we cannot make any assumptions about the ratio between
   *  these moduli, so we will constrain Rx = q * n + Rx' using the foreign field
   *  multiplication gadget, rather than just constraining Rx + 0 with our foreign
   *  field addition gadget.
   *
   *  As we are reducing Rx modulo n, we are performing foreign field arithmetic modulo n.
   *  However, the multiplicand n above is not a valid foreign field element in [0, n - 1].
   *  To be safe we must constrain Rx = q * (n - 1) + q + Rx'  modulo n.
   *)

  (* Compute witness value q and Rx' *)
  let quotient0, quotient1, quotient2, x_prime0, x_prime1, x_prime2 =
    exists (Typ.array ~length:6 Field.typ) ~compute:(fun () ->
        let x =
          Foreign_field.Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            (Affine.x result)
        in

        (* Compute q and r of Rx = q * n + r *)
        let quotient, x_prime =
          Common.bignum_bigint_div_rem x curve.bignum.order
        in

        (* Convert from Bignums to field elements *)
        let quotient0, quotient1, quotient2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            quotient
        in
        let x_prime0, x_prime1, x_prime2 =
          Foreign_field.bignum_bigint_to_field_const_standard_limbs
            (module Circuit)
            x_prime
        in

        (* Return and convert back to Cvars *)
        [| quotient0; quotient1; quotient2; x_prime0; x_prime1; x_prime2 |] )
    |> tuple6_of_array
  in

  (* C8: Constrain q * (n - 1) *)
  let quotient =
    Foreign_field.Element.Standard.of_limbs (quotient0, quotient1, quotient2)
  in
  let quotient_product =
    Foreign_field.mul
      (module Circuit)
      scalar_checks quotient curve.order_minus_one curve.order
  in

  (* Bounds 8: Left input q is bound checked below
   *           Right input (n - 1) is a public parameter so not checked
   *           Result bound check is already covered by scalar_checks
   *)
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs quotient ;

  (* C9: Compute qn = q * (n - 1) + q *)
  let quotient_times_n =
    Foreign_field.add
      (module Circuit)
      ~full:false quotient_product quotient curve.order
  in

  (* Bounds 9: Left input q * (n - 1) is covered by (Bounds 8)
   *           Right input q is covered by (Bounds 8)
   *           Result is chained into subsequent addition (no check necessary)
   *)

  (* C10: Compute Rx = qn + Rx' *)
  let x_prime =
    Foreign_field.Element.Standard.of_limbs (x_prime0, x_prime1, x_prime2)
  in
  let computed_x =
    Foreign_field.add
      (module Circuit)
      ~full:false quotient_times_n x_prime curve.order
  in
  (* Addition chain final result row *)
  Foreign_field.result_row
    (module Circuit)
    ~label:"Ecdsa.verify_computed_x" computed_x ;

  (* Bounds 10: Left input qn is chained input, so not checked
   *            Right input x_prime bounds checked below
   *            Result already bound checked by (Bounds 7)
   *)
  Foreign_field.External_checks.append_bound_check scalar_checks
  @@ Foreign_field.Element.Standard.to_limbs x_prime ;

  (* C11: Check qn + r = Rx *)
  Foreign_field.Element.Standard.assert_equal
    (module Circuit)
    computed_x (Affine.x result) ;

  (* C12: Check that r = Rx' *)
  Foreign_field.Element.Standard.assert_equal (module Circuit) r x_prime ;

  (* C13: Check result is on curve (also implies result is not infinity) *)
  Ec_group.is_on_curve (module Circuit) base_checks curve result ;

  (* Bounds 13: Input already bound checked by (Bounds 8) *)
  ()

(***************)
(* ECDSA tests *)
(***************)

let%test_unit "Ecdsa.verify" =
  if tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Let's test proving ECDSA signature verification in ZK! *)
    let test_verify ?cs ?(use_precomputed_gen_doubles = true)
        ?(scalar_mul_bit_length = 0) (curve : Curve_params.t)
        (pubkey : Affine.bignum_point)
        (signature : Bignum_bigint.t * Bignum_bigint.t)
        (msg_hash : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles
            in
            let pubkey =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) pubkey
            in
            let signature =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (fst signature)
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (snd signature) )
            in
            let msg_hash =
              Foreign_field.Element.Standard.of_bignum_bigint
                (module Runner.Impl)
                msg_hash
            in

            (* Create external checks contexts for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_base_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in
            let unused_scalar_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Subgroup check for pubkey *)
            Ec_group.check_subgroup
              (module Runner.Impl)
              unused_base_checks curve pubkey ;

            (* Check r, s \in [1, n) *)
            signature_scalar_check
              (module Runner.Impl)
              unused_scalar_checks curve signature ;

            (* Verify ECDSA signature *)
            verify
              (module Runner.Impl)
              ~use_precomputed_gen_doubles ~scalar_mul_bit_length
              unused_base_checks unused_scalar_checks curve pubkey signature
              msg_hash ;

            () )
      in

      cs
    in

    (* Test 1: ECDSA verify test with real Ethereum mainnet signature
     *   Tx: https://etherscan.io/tx/0x0d26b1539304a214a6517b529a027f987cd52e70afd8fdc4244569a93121f144
     *
     *   Raw tx: 0xf86580850df8475800830186a094353535353535353535353535353535353535353564801ba082de9950cc5aac0dca7210cb4b77320ac9e844717d39b1781e9d941d920a1206a01da497b3c134f50b2fce514d66e20c5e43f9615f097395a5527041d14860a52f
     *   Msg hash: 0x3e91cd8bd233b3df4e4762b329e2922381da770df1b31276ec77d0557be7fcef
     *   Raw pubkey: 0x046e0f66759bb520b026a9c7d61c82e8354025f2703696dcdac679b2f7945a352e637c8f71379941fa22f15a9fae9cb725ae337b16f216f5acdeefbd52a0882c27
     *   Raw signature: 0x82de9950cc5aac0dca7210cb4b77320ac9e844717d39b1781e9d941d920a12061da497b3c134f50b2fce514d66e20c5e43f9615f097395a5527041d14860a52f1b
     *     r := 0x82de9950cc5aac0dca7210cb4b77320ac9e844717d39b1781e9d941d920a1206
     *     s := 0x1da497b3c134f50b2fce514d66e20c5e43f9615f097395a5527041d14860a52f
     *     v := 27
     *)
    let eth_pubkey =
      ( Bignum_bigint.of_string
          "49781623198970027997721070672560275063607048368575198229673025608762959476014"
      , Bignum_bigint.of_string
          "44999051047832679156664607491606359183507784636787036192076848057884504239143"
      )
    in
    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "59193968509713231970845573191808992654796038550727015999103892005508493218310"
      , (* s *)
        Bignum_bigint.of_string
          "13407882537414256709292360527926092843766608354464979273376653245977131525423"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0x3e91cd8bd233b3df4e4762b329e2922381da770df1b31276ec77d0557be7fcef"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params eth_pubkey) ;

    let _cs =
      test_verify Secp256k1.params ~use_precomputed_gen_doubles:true eth_pubkey
        eth_signature tx_msg_hash
    in

    (* Negative test *)
    assert (
      Common.is_error (fun () ->
          (* Bad hash *)
          let bad_tx_msg_hash =
            Bignum_bigint.of_string
              "0x3e91cd8bd233b3df4e4762b329e2922381da770df1b31276ec77d0557be7fcee"
          in
          test_verify Secp256k1.params eth_pubkey eth_signature bad_tx_msg_hash ) ) ;

    (* Test 2: ECDSA verify test with another real Ethereum mainnet signature
     *   Tx: https://etherscan.io/tx/0x9cec14aadb06b59b2646333f47efe0ee7f21fed48d93806023b8eb205aa3b161
     *
     *   Raw tx: 0x02f9019c018201338405f5e100850cad3895d8830108949440a50cf069e992aa4536211b23f286ef88752187880b1a2bc2ec500000b90124322bba210000000000000000000000008a001303158670e284950565164933372807cd4800000000000000000000000012d220fbda92a9c8f281ea02871afa70dfde81e90000000000000000000000000000000000000000000000000afd4ea3d29472400000000000000000000000000000000000000000461c9bb5bb1c3429b25544e3f4b7bb67d63f9b432df61df28a9897e26284b370adcd7b558fa286babb0efdeb000000000000000000000000000000000000000000000000001cdd1f19bb8dc0000000000000000000000000000000000000000000000000000000006475ed380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a8f2573c080a0893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658fa01119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c422
     *   Msg hash: 0xf7c5983cdb051f68aa84444c4b8ecfdbf60548fe3f5f3f2d19cc5d3c096f0b5b
     *   Raw pubkey: 0x04ad53a68c2120f9a81288b1377adbe7477b7cec1b9b5ff57d5e331ee7f9e6c2372f997b48cf3faa91023f77754ef63ec49dcd5a61b681b53cda894616c28422c0
     *   Raw signature: 0x893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658f1119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c4221c
     *     r := 0x893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658f
     *     s := 0x1119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c422
     *     v := 0
     *)
    let eth_pubkey =
      Ethereum.pubkey_hex_to_point
        "0x04ad53a68c2120f9a81288b1377adbe7477b7cec1b9b5ff57d5e331ee7f9e6c2372f997b48cf3faa91023f77754ef63ec49dcd5a61b681b53cda894616c28422c0"
    in

    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "0x893bc3facf19becba979e31d37ed1b222faab09b8c554a17072f6fbfc1e5658f"
      , (* s *)
        Bignum_bigint.of_string
          "0x1119ef751f0fc3c1ec4d1eeb9db64c9f416ce1aa3267d7b98d8426ab35f0c422"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0xf7c5983cdb051f68aa84444c4b8ecfdbf60548fe3f5f3f2d19cc5d3c096f0b5b"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params eth_pubkey) ;

    let _cs =
      test_verify Secp256k1.params eth_pubkey eth_signature tx_msg_hash
    in

    (* Test 3: ECDSA verify test with yet another real Ethereum mainnet signature
     *   Tx: https://etherscan.io/tx/0x4eb2087dc31dda8fc1bd8680624cd2ae0c1ed0d880de1daefb6fddac208d08fb
     *
     *   Raw tx: 0x02f90114011c8405f5e100850d90b9d72982f4a8948a3749936e723325c6b645a0901470cd9e790b9480b8a8b88d4fde00000000000000000000000085210d346e2baa59a486dd19cf9d18f1325d9ffc00000000000000000000000039f083386e75120d2c6c152900219849dbdaa7e60000000000000000000000000000000000000000000000000000000000000b7100000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000360c6ebec080a0a8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1a031532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1
     *   Msg hash: 0xccdea6d5fce0363b9fbc2cf9a14087fc67c79fbdf55b25789ee2d51dcd82dbc1
     *   Raw pubkey: 0x042b7a248bf6fa2acc079d4f451c68c56a40ef81aeaf6a89c10ed6d692f7a6fdea0c05f95d601c3ab4f75d9253d356ab7af4d7d2ac250e0832581d08f1e224a976
     *   Raw signature: 0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe131532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d11c
     *     r := 0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1
     *     s := 0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1
     *     v := 0
     *)
    let eth_pubkey =
      Ethereum.pubkey_hex_to_point
        "0x042b7a248bf6fa2acc079d4f451c68c56a40ef81aeaf6a89c10ed6d692f7a6fdea0c05f95d601c3ab4f75d9253d356ab7af4d7d2ac250e0832581d08f1e224a976"
    in

    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1"
      , (* s *)
        Bignum_bigint.of_string
          "0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0xccdea6d5fce0363b9fbc2cf9a14087fc67c79fbdf55b25789ee2d51dcd82dbc1"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params eth_pubkey) ;

    let cs =
      test_verify Secp256k1.params eth_pubkey eth_signature tx_msg_hash
    in

    assert (
      Common.is_error (fun () ->
          (* Bad signature *)
          let bad_eth_signature =
            ( (* r *)
              Bignum_bigint.of_string
                "0xc8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1"
            , (* s *)
              Bignum_bigint.of_string
                "0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1"
            )
          in
          test_verify Secp256k1.params eth_pubkey bad_eth_signature tx_msg_hash ) ) ;

    (* Test 4: Constraint system reuse
     *   Tx: https://etherscan.io/tx/0xfc7d65547eb5192c2f35b7e190b4792a9ebf79876f164ead32288e9fe2b7e4f3
     *
     *   Raw tx: 0x02f8730113843b9aca00851405ffdc00825b0494a9d1e08c7793af67e9d92fe308d5697fb81d3e4388299ce7c69d7b9c1780c001a06d5a635efe29deca27e52e96dd2d4056cff1a4b51f88d363f1c3802a26cd67a0a07c34d16c2831ee6265d6d2a55cee6e3273f41480424686d44fe709ce7cfd1567
     *   Msg hash: 0x62c771b337f1a0070dddb863b953017aa12918fc37f338419f7664fda443ce93
     *   Raw pubkey: 0x041d4911ee95f0858df65b942fe88cd54d6c06f73fc9e716db1e153d9994b16930e0284e96e308ef77f1d588aa446237111ab370eeab84059a08980e7e7ab0c467
     *   Raw signature: 0x6d5a635efe29deca27e52e96dd2d4056cff1a4b51f88d363f1c3802a26cd67a07c34d16c2831ee6265d6d2a55cee6e3273f41480424686d44fe709ce7cfd15671b
     *     r := 0xa8c5ae8e178c29a3de4a70ef0d22cbb29a8a0013cfa81fea66885556573debe1
     *     s := 0x31532f9be326029161a4b7bedb80ea4d20b1293cbefb51cc570e72e6aa4ef4d1
     *     v := 1
     *)
    let eth_pubkey =
      Ethereum.pubkey_hex_to_point
        "0x041d4911ee95f0858df65b942fe88cd54d6c06f73fc9e716db1e153d9994b16930e0284e96e308ef77f1d588aa446237111ab370eeab84059a08980e7e7ab0c467"
    in

    let eth_signature =
      ( (* r *)
        Bignum_bigint.of_string
          "0x6d5a635efe29deca27e52e96dd2d4056cff1a4b51f88d363f1c3802a26cd67a0"
      , (* s *)
        Bignum_bigint.of_string
          "0x7c34d16c2831ee6265d6d2a55cee6e3273f41480424686d44fe709ce7cfd1567"
      )
    in
    let tx_msg_hash =
      Bignum_bigint.of_string
        "0x62c771b337f1a0070dddb863b953017aa12918fc37f338419f7664fda443ce93"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params eth_pubkey) ;

    let _cs =
      test_verify ~cs Secp256k1.params eth_pubkey eth_signature tx_msg_hash
    in

    (* Test without using precomputed curve doubles *)
    let _cs =
      test_verify ~use_precomputed_gen_doubles:false Secp256k1.params eth_pubkey
        eth_signature tx_msg_hash
    in

    () )

let%test_unit "Ecdsa.verify_light" =
  if tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Light ecdsa verify circuit for manual checks *)
    let test_verify_light ?cs ?(use_precomputed_gen_doubles = true)
        ?(scalar_mul_bit_length = 0) (curve : Curve_params.t)
        (pubkey : Affine.bignum_point)
        (signature : Bignum_bigint.t * Bignum_bigint.t)
        (msg_hash : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles
            in
            let pubkey =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) pubkey
            in
            Foreign_field.result_row (module Runner.Impl) (fst pubkey) ;
            Foreign_field.result_row (module Runner.Impl) (snd pubkey) ;
            let signature =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (fst signature)
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (snd signature) )
            in
            Foreign_field.result_row (module Runner.Impl) (fst signature) ;
            Foreign_field.result_row (module Runner.Impl) (snd signature) ;
            let msg_hash =
              Foreign_field.Element.Standard.of_bignum_bigint
                (module Runner.Impl)
                msg_hash
            in
            Foreign_field.result_row (module Runner.Impl) msg_hash ;

            (* Create external checks contexts for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_base_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in
            let unused_scalar_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Omit pubkey subgroup check *)

            (* Omit checking r, s \in [1, n) *)

            (* Verify ECDSA signature *)
            verify
              (module Runner.Impl)
              ~use_precomputed_gen_doubles ~scalar_mul_bit_length
              unused_base_checks unused_scalar_checks curve pubkey signature
              msg_hash ;

            (* The base field external check counts depend on curve and scalar size. We elide
             * checking these because we want this test function able to be used with different
             * curves, scalars and other parameters.
             *)

            (* Check scalar field external check counts *)
            assert (Mina_stdlib.List.Length.equal unused_scalar_checks.bounds 5) ;
            assert (
              Mina_stdlib.List.Length.equal unused_scalar_checks.multi_ranges 3 ) ;
            assert (
              Mina_stdlib.List.Length.equal
                unused_scalar_checks.compact_multi_ranges 3 ) ;
            () )
      in

      cs
    in

    (* Tiny secp256k1 signature test: results in 2-bit u1 and u2 scalars
     * Extracted with k = 1 -> secret key = 57896044618658097711785492504343953926418782139537452191302581570759080747168 *)
    let pubkey =
      ( Bignum_bigint.of_string
          "86918276961810349294276103416548851884759982251107"
      , Bignum_bigint.of_string
          "28597260016173315074988046521176122746119865902901063272803125467328307387891"
      )
    in
    let signature =
      ( (* r = Gx *)
        Bignum_bigint.of_string
          "55066263022277343669578718895168534326250603453777594175500187360389116729240"
      , (* s = r/2 *)
        Bignum_bigint.of_string
          "27533131511138671834789359447584267163125301726888797087750093680194558364620"
      )
    in
    let msg_hash =
      (* z = 2s *)
      Bignum_bigint.of_string
        "55066263022277343669578718895168534326250603453777594175500187360389116729240"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params pubkey) ;

    let _cs =
      test_verify_light Secp256k1.params ~scalar_mul_bit_length:2 pubkey
        signature msg_hash
    in
    let _cs =
      test_verify_light Secp256k1.params ~use_precomputed_gen_doubles:false
        ~scalar_mul_bit_length:2 pubkey signature msg_hash
    in

    () )

let%test_unit "Ecdsa.secp256k1_verify_tiny_full" =
  if tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Tiny full circuit for ecdsa on secp256k1 manual checks.
     * Note: pubkey, signature and msg_hash need to be specially crafted to produce 2-bit scalars
     *)
    let secp256k1_verify_tiny_full ?cs ?(use_precomputed_gen_doubles = true)
        (pubkey : Affine.bignum_point)
        (signature : Bignum_bigint.t * Bignum_bigint.t)
        (msg_hash : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                Secp256k1.params ~use_precomputed_gen_doubles
            in
            let pubkey =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) pubkey
            in
            Foreign_field.result_row (module Runner.Impl) (fst pubkey) ;
            Foreign_field.result_row (module Runner.Impl) (snd pubkey) ;
            let signature =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (fst signature)
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (snd signature) )
            in
            Foreign_field.result_row (module Runner.Impl) (fst signature) ;
            Foreign_field.result_row (module Runner.Impl) (snd signature) ;
            let msg_hash =
              Foreign_field.Element.Standard.of_bignum_bigint
                (module Runner.Impl)
                msg_hash
            in
            Foreign_field.result_row (module Runner.Impl) msg_hash ;

            (* Create external checks contexts for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let base_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in
            let scalar_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Omit pubkey subgroup check *)

            (* Omit checking r, s \in [1, n) *)

            (* Verify ECDSA signature *)
            verify
              (module Runner.Impl)
              ~use_precomputed_gen_doubles ~scalar_mul_bit_length:2 base_checks
              scalar_checks curve pubkey signature msg_hash ;

            (*
             * Perform base field external checks
             *)

            (* Sanity check *)
            let base_bound_checks_count = ref (42 + 2 + 42 + 2 + 6 + 2 + 3) in
            if not Bignum_bigint.(curve.bignum.a = zero) then
              base_bound_checks_count := !base_bound_checks_count + 2 ;
            if not Bignum_bigint.(curve.bignum.b = zero) then
              base_bound_checks_count := !base_bound_checks_count + 1 ;
            assert (
              Mina_stdlib.List.Length.equal base_checks.bounds
                !base_bound_checks_count ) ;
            assert (Mina_stdlib.List.Length.equal base_checks.multi_ranges 40) ;
            assert (
              Mina_stdlib.List.Length.equal base_checks.compact_multi_ranges 40 ) ;

            (* Add gates for bound checks, multi-range-checks and compact-multi-range-checks *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              base_checks curve.modulus ;

            (*
             * Perform scalar field external checks
             *)

            (* Sanity checks *)
            assert (Mina_stdlib.List.Length.equal scalar_checks.bounds 5) ;
            assert (Mina_stdlib.List.Length.equal scalar_checks.multi_ranges 3) ;
            assert (
              Mina_stdlib.List.Length.equal scalar_checks.compact_multi_ranges 3 ) ;

            (* Add gates for bound checks, multi-range-checks and compact-multi-range-checks *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              scalar_checks curve.order ;

            () )
      in

      cs
    in

    (* Tiny secp256k1 signature test: results in 2-bit u1 and u2 scalars
     * Extracted with k = 1 -> secret key = 57896044618658097711785492504343953926418782139537452191302581570759080747168 *)
    let pubkey =
      (* secret key d = (s - z)/r *)
      ( Bignum_bigint.of_string
          "86918276961810349294276103416548851884759982251107"
      , Bignum_bigint.of_string
          "28597260016173315074988046521176122746119865902901063272803125467328307387891"
      )
    in
    let signature =
      ( (* r = Gx *)
        Bignum_bigint.of_string
          "55066263022277343669578718895168534326250603453777594175500187360389116729240"
      , (* s = r/2 *)
        Bignum_bigint.of_string
          "27533131511138671834789359447584267163125301726888797087750093680194558364620"
      )
    in
    let msg_hash =
      (* z = 2s *)
      Bignum_bigint.of_string
        "55066263022277343669578718895168534326250603453777594175500187360389116729240"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params pubkey) ;

    let _cs =
      secp256k1_verify_tiny_full ~use_precomputed_gen_doubles:false pubkey
        signature msg_hash
    in

    () )

let%test_unit "Ecdsa.verify_full_no_subgroup_check" =
  if tests_enabled then (
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Prove ECDSA signature verification in ZK (no subgroup check)! *)
    let test_verify_full_no_subgroup_check ?cs
        ?(use_precomputed_gen_doubles = true) ?(scalar_mul_bit_length = 0)
        (curve : Curve_params.t) (pubkey : Affine.bignum_point)
        (signature : Bignum_bigint.t * Bignum_bigint.t)
        (msg_hash : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            (* Prepare test inputs *)
            let curve =
              Curve_params.to_circuit_constants
                (module Runner.Impl)
                curve ~use_precomputed_gen_doubles
            in
            let pubkey =
              Affine.of_bignum_bigint_coordinates (module Runner.Impl) pubkey
            in
            let signature =
              ( Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (fst signature)
              , Foreign_field.Element.Standard.of_bignum_bigint
                  (module Runner.Impl)
                  (snd signature) )
            in
            let msg_hash =
              Foreign_field.Element.Standard.of_bignum_bigint
                (module Runner.Impl)
                msg_hash
            in

            (* Create external checks contexts for tracking extra constraints
               that are required for soundness *)
            let base_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in
            let scalar_checks =
              Foreign_field.External_checks.create (module Runner.Impl)
            in

            (* Subgroup check for pubkey is too expensive for test without chunking *)

            (* Check r, s \in [1, n) *)
            signature_scalar_check
              (module Runner.Impl)
              scalar_checks curve signature ;

            (* Verify ECDSA signature *)
            verify
              (module Runner.Impl)
              ~use_precomputed_gen_doubles ~scalar_mul_bit_length base_checks
              scalar_checks curve pubkey signature msg_hash ;

            (*
             * Perform base field external checks
             *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              base_checks curve.modulus ;

            (*
             * Perform scalar field external checks
             *)
            Foreign_field.constrain_external_checks
              (module Runner.Impl)
              scalar_checks curve.order ;

            () )
      in

      cs
    in

    (* Test 1: No chunking (big test that doesn't require chunkning)
     *         Uses precomputed generator doubles.
     *         Extracted s,d such that that u1 and u2 scalars are equal to m = 95117056129877063566687163501128961107874747202063760588013341337 (216 bits) *)
    let pubkey =
      (* secret key d = (s - z)/r *)
      ( Bignum_bigint.of_string
          "28335432349034412295843546619549969371276098848890005110917167585721026348383"
      , Bignum_bigint.of_string
          "40779711449769771629236800666139862371172776689379727569918249313574127557987"
      )
    in
    let signature =
      ( (* r = Gx *)
        Bignum_bigint.of_string
          "55066263022277343669578718895168534326250603453777594175500187360389116729240"
      , (* s = r/m *)
        Bignum_bigint.of_string
          "92890023769187417206640608811117482540691917151111621018323984641303111040093"
      )
    in
    let msg_hash =
      (* z = ms *)
      Bignum_bigint.of_string
        "55066263022277343669578718895168534326250603453777594175500187360389116729240"
    in

    assert (Ec_group.is_on_curve_bignum_point Secp256k1.params pubkey) ;

    let _cs =
      test_verify_full_no_subgroup_check Secp256k1.params
        ~scalar_mul_bit_length:216 pubkey signature msg_hash
    in

    (* Test 2: No chunking (big test that doesn't require chunkning)
     *         Extracted s,d such that that u1 and u2 scalars are equal to m = 177225723614878382952356121702918977654 (128 bits) *)
    let pubkey =
      (* secret key d = (s - z)/r *)
      ( Bignum_bigint.of_string
          "6559447345535823731364817861985473100513487071640065635466595453031721007862"
      , Bignum_bigint.of_string
          "74970879557849263394678708702512922877596422437120940411392434995042287566169"
      )
    in
    let signature =
      ( (* r = Gx *)
        Bignum_bigint.of_string
          "55066263022277343669578718895168534326250603453777594175500187360389116729240"
      , (* s = r/m *)
        Bignum_bigint.of_string
          "66524399747416926971392827702286928407253072170352243437129959464602950571595"
      )
    in
    let msg_hash =
      (* z = ms *)
      Bignum_bigint.of_string
        "55066263022277343669578718895168534326250603453777594175500187360389116729240"
    in

    let _cs =
      test_verify_full_no_subgroup_check Secp256k1.params
        ~use_precomputed_gen_doubles:false ~scalar_mul_bit_length:128 pubkey
        signature msg_hash
    in

    () )
