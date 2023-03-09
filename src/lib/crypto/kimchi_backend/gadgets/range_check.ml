open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* 64-bit range-check gadget *)
let range_check64 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (v0 : Circuit.Field.t) =
  let open Circuit in
  (* Create sublimbs *)
  let v0p2 = Common.field_bits_le_to_field (module Circuit) v0 52 64 in
  let v0p3 = Common.field_bits_le_to_field (module Circuit) v0 40 52 in
  let v0p4 = Common.field_bits_le_to_field (module Circuit) v0 28 40 in
  let v0p5 = Common.field_bits_le_to_field (module Circuit) v0 16 28 in
  let v0c0 = Common.field_bits_le_to_field (module Circuit) v0 14 16 in
  let v0c1 = Common.field_bits_le_to_field (module Circuit) v0 12 14 in
  let v0c2 = Common.field_bits_le_to_field (module Circuit) v0 10 12 in
  let v0c3 = Common.field_bits_le_to_field (module Circuit) v0 8 10 in
  let v0c4 = Common.field_bits_le_to_field (module Circuit) v0 6 8 in
  let v0c5 = Common.field_bits_le_to_field (module Circuit) v0 4 6 in
  let v0c6 = Common.field_bits_le_to_field (module Circuit) v0 2 4 in
  let v0c7 = Common.field_bits_le_to_field (module Circuit) v0 0 2 in

  (* Generic gate with Zero needed ? *)

  (* Copy constraints needed ? *)

  (* Create RangeCheck0 gate *)
  with_label "range_check64" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (RangeCheck0
                 { (* Current row *) v0
                 ; v0p0 = Field.zero
                 ; v0p1 = Field.zero
                 ; v0p2
                 ; v0p3
                 ; v0p4
                 ; v0p5
                 ; v0c0
                 ; v0c1
                 ; v0c2
                 ; v0c3
                 ; v0c4
                 ; v0c5
                 ; v0c6
                 ; v0c7
                 ; (* Coefficients *)
                   compact = Field.Constant.zero
                 } )
        } )

let%test_unit "range_check64 gadget" =
  Printf.printf "range_check64 gadget test\n" ;
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in

  (* Helper to test range_check64 gadget
   *   Input: value to be range checked in [0, 2^64)
   *)
  let _test_range_check64 base10 : bool =
    try
      let _proof_keypair, _proof =
        Runner.generate_and_verify_proof (fun () ->
            let open Runner.Impl in
            let value =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_string base10 )
            in
            range_check64 (module Runner.Impl) value ;
            (* Padding *)
            Boolean.Assert.is_true (Field.equal value value) )
      in
      true
    with exn ->
      Format.eprintf "Error: %s@." (Exn.to_string exn) ;
      Printexc.print_backtrace Stdlib.stdout ;
      Stdlib.(flush stdout) ;
      false
  in

  (* Positive tests *)
  (* assert (Bool.equal (test_range_check64 "0") true) ; *)
  (* assert (Bool.equal (test_range_check64 "4294967") true) ;
     assert (Bool.equal (test_range_check64 "18446744073709551615") true) ; *)
  (* Negative tests *)
  (* assert (Bool.equal (test_range_check64 "18446744073709551616") false) ;
     assert (
       Bool.equal
         (test_range_check64 "170141183460469231731687303715884105728")
         false ) ; *)
  ()
