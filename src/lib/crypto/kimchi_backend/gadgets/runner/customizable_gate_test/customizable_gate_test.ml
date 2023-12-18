open Kimchi_gadgets_test_runner.Runner

let () = Tick.Keypair.set_urs_info []

let test_foreign_field_add ~valid_witness ?cs () =
  let cs, _proof_keypair, _proof =
    generate_and_verify_proof_plus None ?cs (fun () ->
        let open Impl in
        let output =
          if valid_witness then Field.of_int 70 else Field.of_int 71
        in
        with_label "foreign_field_add (ffadd)" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (ForeignFieldAdd
                       { left_input_lo = Field.of_int 7
                       ; left_input_mi = Field.zero
                       ; left_input_hi = Field.zero
                       ; right_input_lo = Field.of_int 63
                       ; right_input_mi = Field.zero
                       ; right_input_hi = Field.zero
                       ; field_overflow = Field.zero
                       ; carry = Field.zero
                       ; foreign_field_modulus0 = Field.Constant.of_int 7919
                       ; foreign_field_modulus1 = Field.Constant.zero
                       ; foreign_field_modulus2 = Field.Constant.zero
                       ; sign = Field.Constant.one
                       } )
              } ) ;

        with_label "foreign_field_add (result)" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (Raw
                       { kind = Zero
                       ; values = [| output; Field.zero; Field.zero |]
                       ; coeffs = [||]
                       } )
              } ) )
  in
  cs

let test_conditional ~valid_witness ?cs () =
  let cs, _proof_keypair, _proof =
    (* User-supplied conditional gate in RPN
     *     w(0) = w(1) * w(3) + (1 - w(3)) * w(2)
     *)
    let conditional_gate =
      Some
        Kimchi_types.
          [| Cell { col = Index ForeignFieldAdd; row = Curr }
           ; Cell { col = Witness 3; row = Curr }
           ; Dup
           ; Mul
           ; Cell { col = Witness 3; row = Curr }
           ; Sub
           ; Alpha
           ; Pow 1l
           ; Cell { col = Witness 0; row = Curr }
           ; Cell { col = Witness 3; row = Curr }
           ; Cell { col = Witness 1; row = Curr }
           ; Mul
           ; Literal (Impl.Field.Constant.of_int 1)
           ; Cell { col = Witness 3; row = Curr }
           ; Sub
           ; Cell { col = Witness 2; row = Curr }
           ; Mul
           ; Add
           ; Sub
           ; Mul
           ; Add
           ; Mul
          |]
    in
    generate_and_verify_proof_plus conditional_gate ?cs (fun () ->
        let open Impl in
        let output = if valid_witness then Field.one else Field.zero in
        with_label "foreign_field_add (conditional)" (fun () ->
            assert_
              { annotation = Some __LOC__
              ; basic =
                  Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint
                  .T
                    (ForeignFieldAdd
                       { left_input_lo = output (* Conditional output *)
                       ; left_input_mi = Field.one (* Conditional x *)
                       ; left_input_hi = Field.zero (* Conditional y *)
                       ; right_input_lo = Field.of_int 1 (* Conditional b *)
                       ; right_input_mi = Field.zero
                       ; right_input_hi = Field.zero
                       ; field_overflow = Field.zero
                       ; carry = Field.zero
                       ; foreign_field_modulus0 = Field.Constant.one
                       ; foreign_field_modulus1 = Field.Constant.zero
                       ; foreign_field_modulus2 = Field.Constant.one
                       ; sign = Field.Constant.zero
                       } )
              } ) )
  in
  cs

(* Test ForeignFieldAdd (valid witness) *)
let _cs = test_foreign_field_add ~valid_witness:true ()

(* Test ForeignFieldAdd (invalid witness) *)
let () =
  let test_failed =
    try
      let _cs = test_foreign_field_add ~valid_witness:false () in
      false
    with _ -> true
  in
  assert test_failed

(* Test Conditional (valid witness) *)
let _cs = test_conditional ~valid_witness:true ()

(* Test Conditional (invalid witness) *)
let () =
   let test_failed =
     try
       let _cs = test_conditional ~valid_witness:false () in
       false
     with _ -> true
   in
   assert test_failed
