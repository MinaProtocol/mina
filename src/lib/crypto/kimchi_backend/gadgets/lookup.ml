open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let tests_enabled = true

(* Looks up three values (at most 12 bits each) 
 * BEWARE: it needs in the circuit at least one gate (even if dummy) that uses the 12-bit lookup table for it to work 
 *)
let three_12bit (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v0 : Circuit.Field.t) (v1 : Circuit.Field.t) (v2 : Circuit.Field.t) : unit
    =
  let open Circuit in
  with_label "triple_lookup" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Lookup
                 { w0 = Field.one
                 ; w1 = v0
                 ; w2 = Field.zero
                 ; w3 = v1
                 ; w4 = Field.zero
                 ; w5 = v2
                 ; w6 = Field.zero
                 } )
        } ) ;
  ()

(* Check that one value is at most X bits (at most 12), default is 12.
 * BEWARE: it needs in the circuit at least one gate (even if dummy) that uses the 12-bit lookup table for it to work 
 *)
let less_than_bits (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(bits = 12) (value : Circuit.Field.t) : unit =
  let open Circuit in
  assert (bits > 0 && bits <= 12) ;
  (* In order to check that a value is less than 2^x bits value < 2^x
     you first check that value < 2^12 bits using the lookup table
     and then that the value * shift < 2^12 where shift = 2^(12-x)
     (because moving shift to the right hand side that gives value < 2^x) *)
  let shift =
    exists Field.typ ~compute:(fun () ->
        let power = Core_kernel.Int.pow 2 (12 - bits) in
        Field.Constant.of_int power )
  in
  three_12bit (module Circuit) value Field.(value * shift) Field.zero ;
  ()

(*********)
(* Tests *)
(*********)

let%test_unit "lookup gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test lookup less than gadget for both variables and constants
     *   Inputs value to be checked and number of bits
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_lookup ?cs ~bits value =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Set up snarky constant *)
            let const = Field.constant @@ Field.Constant.of_int value in
            (* Set up snarky variable *)
            let value =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int value)
            in
            (* Use the lookup gadget *)
            less_than_bits (module Runner.Impl) ~bits value ;
            less_than_bits (module Runner.Impl) ~bits const ;
            (* Use a dummy range check to load the table *)
            Range_check.bits64 (module Runner.Impl) Field.zero ;
            () )
      in
      cs
    in

    (* TEST generic mul gadget *)
    (* Positive tests *)
    let cs12 = test_lookup ~bits:12 4095 in
    let cs8 = test_lookup ~bits:8 255 in
    let cs1 = test_lookup ~bits:1 0 in
    let _cs = test_lookup ~cs:cs1 ~bits:1 1 in
    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_lookup ~cs:cs12 ~bits:12 4096)) ;
    assert (Common.is_error (fun () -> test_lookup ~cs:cs12 ~bits:12 (-1))) ;
    assert (Common.is_error (fun () -> test_lookup ~cs:cs8 ~bits:8 256)) ;
    assert (Common.is_error (fun () -> test_lookup ~cs:cs1 ~bits:1 2)) ;
    () ) ;

  ()
