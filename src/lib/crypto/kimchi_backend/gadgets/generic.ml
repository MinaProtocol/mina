open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

(* EXAMPLE generic addition gate gadget *)
let add (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) :
    Circuit.Field.t =
  let open Circuit in
  (* Witness computation; sum = left_input + right_input *)
  let sum =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.add left_input right_input )
  in

  (* Set up generic add gate *)
  with_label "generic_add_gadget" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, left_input)
                 ; r = (Field.Constant.one, right_input)
                 ; o = (Option.value_exn Field.(to_constant (negate one)), sum)
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } ;
      sum )

(* EXAMPLE generic multiplication gate gadget *)
let mul (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) :
    Circuit.Field.t =
  let open Circuit in
  (* Witness computation: prod = left_input + right_input *)
  let prod =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.mul left_input right_input )
  in

  (* Set up generic mul gate *)
  with_label "generic_mul_gadget" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.zero, left_input)
                 ; r = (Field.Constant.zero, right_input)
                 ; o = (Option.value_exn Field.(to_constant (negate one)), prod)
                 ; m = Field.Constant.one
                 ; c = Field.Constant.zero
                 } )
        } ;
      prod )

let%test_unit "generic gadgets" =
  (* Import the gadget test runner *)
  let open Kimchi_gadgets_test_runner in
  (* Initialize the SRS cache. *)
  let () = Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] in

  (* Helper to test generic add gate gadget
   *   Inputs operands and expected output: left_input + right_input = sum
   *   Returns true if constraints are satisfied, false otherwise.
   *)
  let test_generic_add left_input right_input sum =
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
            let sum =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int sum)
            in
            (* Use the generic add gate gadget *)
            let result = add (module Runner.Impl) left_input right_input in
            Field.Assert.equal sum result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true (Field.equal sum sum) )
      in
      true
    with _ -> false
  in

  (* Helper to test generic multimplication gate gadget
   *   Inputs operands and expected output: left_input * right_input = prod
   *   Returns true if constraints are satisfied, false otherwise.
   *)
  let test_generic_mul left_input right_input prod =
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
            let prod =
              exists Field.typ ~compute:(fun () -> Field.Constant.of_int prod)
            in
            (* Use the generic mul gate gadget *)
            let result = mul (module Runner.Impl) left_input right_input in
            Field.Assert.equal prod result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true (Field.equal prod prod) )
      in
      true
    with _ -> false
  in

  (* TEST generic add gadget *)
  (* Positive tests *)
  assert (Bool.equal (test_generic_add 0 0 0) true) ;
  assert (Bool.equal (test_generic_add 1 2 3) true) ;
  (* Negatve tests *)
  assert (Bool.equal (test_generic_add 1 0 0) false) ;
  assert (Bool.equal (test_generic_add 2 4 7) false) ;

  (* TEST generic mul gadget *)
  (* Positive tests *)
  assert (Bool.equal (test_generic_mul 0 0 0) true) ;
  assert (Bool.equal (test_generic_mul 1 2 2) true) ;
  (* Negatve tests *)
  assert (Bool.equal (test_generic_mul 1 0 1) false) ;
  assert (Bool.equal (test_generic_mul 2 4 7) false) ;

  ()
