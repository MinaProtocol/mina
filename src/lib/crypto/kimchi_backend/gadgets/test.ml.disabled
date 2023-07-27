let tests_enabled = true

let%test_unit "custom gates integration" =
  ( if tests_enabled then
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    let open Foreign_field in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Convert Bignum_bigint.t to Bignum_bigint standard_limbs *)
    let bignum_bigint_to_standard_limbs (bigint : Bignum_bigint.t) :
        Bignum_bigint.t standard_limbs =
      let l12, l0 = Common.(bignum_bigint_div_rem bigint two_to_limb) in
      let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
      (l0, l1, l2)
    in

    (* Convert Bignum_bigint.t to field standard_limbs *)
    let bignum_bigint_to_field_const_standard_limbs (type f)
        (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
        (bigint : Bignum_bigint.t) : f standard_limbs =
      let l0, l1, l2 = bignum_bigint_to_standard_limbs bigint in
      ( Common.bignum_bigint_to_field (module Circuit) l0
      , Common.bignum_bigint_to_field (module Circuit) l1
      , Common.bignum_bigint_to_field (module Circuit) l2 )
    in

    (* Helper to test all custom gates for Ethereum primitives.
     * The circuit being created is the following:
     * - rotate first 64-bit word by 5 bits to the right
     * - multiply by 2^176
     * - xor it with the second word which is a native field element (255 bits)
     * - and it with the first word (254 bits)
     * - not the output for 254 bits
     * - create limbs for the output and decompose
     * - multiply it with itself (256 bits)
     * - ffadd it with the third input which is a foreign element (256 bits)
     * - multi range check the 3 limbs of the output
     *)
    let test_gates ?cs word_64bit native_elem foreign_elem =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            let open Bitwise in
            let secp256k1_modulus =
              bignum_bigint_to_field_const_standard_limbs (module Runner.Impl)
              @@ Common.bignum_bigint_of_hex
                   "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
            in

            (* Set up snarky variables for inputs and outputs *)
            let word_64bit =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) word_64bit )
            in
            let native_elem =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex (module Runner.Impl) native_elem )
            in
            let foreign_elem =
              Element.Standard.of_bignum_bigint (module Runner.Impl)
              @@ Common.bignum_bigint_of_hex foreign_elem
            in
            let out_rot = rot64 (module Runner.Impl) word_64bit 5 Right in

            let two_to_88 =
              exists Field.typ ~compute:(fun () ->
                  Common.field_of_hex
                    (module Runner.Impl)
                    "10000000000000000000000" )
            in
            let two_to_176 = Field.(two_to_88 * two_to_88) in

            let out_mul = Generic.mul (module Runner.Impl) out_rot two_to_176 in
            let out_xor = bxor (module Runner.Impl) out_mul native_elem 255 in
            let out_and = band (module Runner.Impl) out_xor word_64bit 254 in
            let out_not_c = bnot_checked (module Runner.Impl) out_and 254 in
            let out_not_u = bnot_unchecked (module Runner.Impl) out_and 254 in
            Field.Assert.equal out_not_u out_not_c ;

            let l0, l1, l2 =
              exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
                  let big =
                    Common.cvar_field_to_bignum_bigint_as_prover
                      (module Runner.Impl)
                      out_not_c
                  in
                  let two_to_88 = Bignum_bigint.(pow (of_int 2) (of_int 88)) in
                  let two_to_176 =
                    Bignum_bigint.(pow (of_int 2) (of_int 176))
                  in
                  let l2 = Bignum_bigint.(big / two_to_176) in
                  let l1 =
                    Bignum_bigint.((big - (l2 * two_to_176)) / two_to_88)
                  in
                  let l0 =
                    Bignum_bigint.(big - (l2 * two_to_176) - (l1 * two_to_88))
                  in
                  let l2 =
                    Common.bignum_bigint_to_field (module Runner.Impl) l2
                  in
                  let l1 =
                    Common.bignum_bigint_to_field (module Runner.Impl) l1
                  in
                  let l0 =
                    Common.bignum_bigint_to_field (module Runner.Impl) l0
                  in
                  [| l0; l1; l2 |] )
              |> Common.tuple3_of_array
            in
            let out_l1 = Generic.mul (module Runner.Impl) l1 two_to_88 in
            let out_l1l0 = Generic.add (module Runner.Impl) out_l1 l0 in
            let out_l2 = Generic.mul (module Runner.Impl) l2 two_to_176 in
            let out_limbs = Generic.add (module Runner.Impl) out_l1l0 out_l2 in
            Field.Assert.equal out_limbs out_not_c ;
            let limbs = Element.Standard.of_limbs (l0, l1, l2) in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (not used in this test) *)
            let unused_external_checks =
              External_checks.create (module Runner.Impl)
            in

            let out_ffmul =
              Foreign_field.mul
                (module Runner.Impl)
                unused_external_checks limbs limbs secp256k1_modulus
            in

            let out_ffadd =
              Foreign_field.add
                (module Runner.Impl)
                out_ffmul foreign_elem secp256k1_modulus
            in
            let l0, l1, l2 = Element.Standard.to_limbs out_ffadd in
            Range_check.multi (module Runner.Impl) l0 l1 l2 ;
            () )
      in
      cs
    in

    let cs =
      test_gates "7b3f28d7496d75f0"
        "3fffe27b14baa740db0c8bb6656de61d2871a64093908af6181f46351a1c1909"
        "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2"
    in
    let _cs =
      test_gates ~cs "84c0d728b6928a0f"
        "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d"
        "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    in
    () ) ;
  ()
