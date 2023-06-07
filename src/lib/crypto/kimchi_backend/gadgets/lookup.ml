open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let tests_enabled = true

(** Looks up three values (at most 12 bits) *)
let three_values (type f)
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

(** Check that one value is at most X bits (at most 12) *)
let less_than_bits (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bits : int) (value : Circuit.Field.t) : unit =
  let open Circuit in
  assert (bits > 0 && bits <= 12) ;
  let shift =
    exists Field.typ ~compute:(fun () ->
        let power = Core_kernel.Int.pow 2 (12 - bits) in
        Field.Constant.of_int power )
  in
  three_values (module Circuit) value Field.(value * shift) Field.zero ;
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

    (* Helper to test lookup less than gadget
     *   Inputs value to be checked and number of bits
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_lookup ?cs ~bits value =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Set up snarky variable *)
            let value =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int value)
            in
            (* Use the lookup gadget *)
            less_than_bits (module Runner.Impl) bits value ;
            () )
      in
      cs
    in

    (* TEST generic mul gadget *)
    (* Positive tests *)
    let cs12 = test_lookup ~bits:12 4095 in
    let cs8 = test_lookup ~bits:8 255 in
    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_lookup ~cs:cs12 ~bits:12 4096)) ;
    assert (Common.is_error (fun () -> test_lookup ~cs:cs8 ~bits:8 256)) ;
    () ) ;

  ()
