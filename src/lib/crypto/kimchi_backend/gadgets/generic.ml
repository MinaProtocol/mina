open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let tests_enabled = true

(* Generic addition gate gadget *)
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

  let neg_one = Field.Constant.(negate one) in
  (* Set up generic add gate *)
  with_label "generic_add_gadget" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, left_input)
                 ; r = (Field.Constant.one, right_input)
                 ; o = (neg_one, sum)
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } ;
      sum )

(* Generic constant addition gadget (right operand is constant)
 *   Instead of constraining constant in separate generic gate, this gadget allows the constant
 *   to be specified as a coefficient of the generic addition gate; thus, savings a row.
 *)
let add_const (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (left_input : Circuit.Field.t) (right_input : f) : Circuit.Field.t =
  let open Circuit in
  (* Witness computation; sum = left_input + right_input *)
  let sum =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        Field.Constant.add left_input right_input )
  in

  let neg_one = Field.Constant.(negate one) in
  (* Set up generic add gate *)
  with_label "generic_add_const_gadget" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, left_input)
                 ; r = (Field.Constant.zero, Field.(constant Constant.zero))
                 ; o = (neg_one, sum)
                 ; m = Field.Constant.zero
                 ; c = right_input
                 } )
        } ;
      sum )

(* Generic subtraction gate gadget *)
let sub (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (left_input : Circuit.Field.t) (right_input : Circuit.Field.t) :
    Circuit.Field.t =
  let open Circuit in
  (* Witness computation; difference = left_input - right_input *)
  let difference =
    exists Field.typ ~compute:(fun () ->
        let left_input = As_prover.read Field.typ left_input in
        let right_input = As_prover.read Field.typ right_input in
        Field.Constant.sub left_input right_input )
  in

  (* Negative one gate coefficient *)
  let neg_one = Field.Constant.(negate one) in

  (* Set up generic sub gate *)
  with_label "generic_sub_gadget" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.one, left_input)
                 ; r = (neg_one, right_input)
                 ; o = (neg_one, difference)
                 ; m = Field.Constant.zero
                 ; c = Field.Constant.zero
                 } )
        } ;
      difference )

(* Generic multiplication gate gadget *)
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

  let neg_one = Field.Constant.(negate one) in
  (* Set up generic mul gate *)
  with_label "generic_mul_gadget" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Basic
                 { l = (Field.Constant.zero, left_input)
                 ; r = (Field.Constant.zero, right_input)
                 ; o = (neg_one, prod)
                 ; m = Field.Constant.one
                 ; c = Field.Constant.zero
                 } )
        } ;
      prod )

(*********)
(* Tests *)
(*********)

let%test_unit "generic gadgets" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test generic add gate gadget
     *   Inputs operands and expected output: left_input + right_input = sum
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_generic_add ?cs left_input right_input sum =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
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

      cs
    in

    (* Helper to test generic sub gate gadget
     *   Inputs operands and expected output: left_input - right_input = difference
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_generic_sub ?cs left_input right_input difference =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
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
            let difference =
              exists Field.typ ~compute:(fun () ->
                  Field.Constant.of_int difference )
            in
            (* Use the generic sub gate gadget *)
            let result = sub (module Runner.Impl) left_input right_input in
            Field.Assert.equal difference result ;
            (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
            Boolean.Assert.is_true (Field.equal difference difference) )
      in

      cs
    in

    (* Helper to test generic multimplication gate gadget
     *   Inputs operands and expected output: left_input * right_input = prod
     *   Returns true if constraints are satisfied, false otherwise.
     *)
    let test_generic_mul ?cs left_input right_input prod =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
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

      cs
    in

    (* TEST generic add gadget *)
    (* Positive tests *)
    let cs = test_generic_add 0 0 0 in
    let _cs = test_generic_add ~cs 1 2 3 in
    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_generic_add ~cs 1 0 0)) ;
    assert (Common.is_error (fun () -> test_generic_add ~cs 2 4 7)) ;

    (* TEST generic sub gadget *)
    (* Positive tests *)
    let cs = test_generic_sub 0 0 0 in
    let _cs = test_generic_sub ~cs 2 1 1 in
    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_generic_sub ~cs 4 2 1)) ;
    assert (Common.is_error (fun () -> test_generic_sub ~cs 13 4 10)) ;

    (* TEST generic mul gadget *)
    (* Positive tests *)
    let cs = test_generic_mul 0 0 0 in
    let _cs = test_generic_mul ~cs 1 2 2 in
    (* Negatve tests *)
    assert (Common.is_error (fun () -> test_generic_mul ~cs 1 0 1)) ;
    assert (Common.is_error (fun () -> test_generic_mul ~cs 2 4 7)) ) ;
  ()
