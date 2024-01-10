open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let perform_step_tests = true

let perform_recursive_tests = false

let perform_step_choices_test = false

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let constraint_constants =
  { Snark_keys_header.Constraint_constants.sub_windows_per_window = 0
  ; ledger_depth = 0
  ; work_delay = 0
  ; block_window_duration_ms = 0
  ; transaction_capacity = Log_2 0
  ; pending_coinbase_depth = 0
  ; coinbase_amount = Unsigned.UInt64.of_int 0
  ; supercharged_coinbase_factor = 0
  ; account_creation_fee = Unsigned.UInt64.of_int 0
  ; fork = None
  }

let create_customisable_circuit ~custom_gate_type ~valid_witness =
  (* Create the witness corresponding to the config of customizable
     gate as either ForeignFieldAdd or Conditional gate
     and make it either valid or invalid *)
  let cell1, cell2, cell3, cell4, result =
    if Option.is_some custom_gate_type then
      ( ( if valid_witness then Field.one
        else Field.zero (* Conditional output *) )
      , Field.one (* Conditional x *)
      , Field.zero (* Conditional y *)
      , Field.one (* Conditional b *)
      , Field.zero )
    else
      ( Field.of_int 7
      , Field.zero
      , Field.zero
      , Field.of_int 63
      , if valid_witness then Field.of_int 70 else Field.of_int 71 )
  in
  with_label "customizable gate (ffadd)" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldAdd
                 { left_input_lo = cell1
                 ; left_input_mi = cell2
                 ; left_input_hi = cell3
                 ; right_input_lo = cell4
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

  with_label "customizable gate (result)" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Raw
                 { kind = Zero
                 ; values = [| result; Field.zero; Field.zero |]
                 ; coeffs = [||]
                 } )
        } )

let test ~step_only ~custom_gate_type ~valid_witness =
  let tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~name:"customizable gate"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "customizable gate"
          ; prevs = []
          ; main =
              (fun _ ->
                create_customisable_circuit ~custom_gate_type ~valid_witness ;

                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags =
              Pickles_types.Plonk_types.Features.
                { none_bool with foreign_field_add = true }
          ; custom_gate_type
          }
        ] )
      ()
  in

  let module Proof = (val proof) in
  let test_prove () =
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () -> prove ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input, proof) ] ) ) ;

    if not step_only then
      let module Requests = struct
        type _ Snarky_backendless.Request.t +=
          | Proof :
              (Nat.N0.n, Nat.N0.n) Pickles.Proof.t Snarky_backendless.Request.t

        let handler (proof : _ Pickles.Proof.t)
            (Snarky_backendless.Request.With { request; respond }) =
          match request with
          | Proof ->
              respond (Provide proof)
          | _ ->
              respond Unhandled
      end in
      let ( _tag
          , _cache_handle
          , recursive_proof
          , Pickles.Provers.[ recursive_prove ] ) =
        Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
          ~auxiliary_typ:Typ.unit
          ~branches:(module Nat.N1)
          ~max_proofs_verified:(module Nat.N1)
          ~name:"recursion over customizable gate"
          ~constraint_constants
            (* TODO(mrmr1993): This was misguided.. Delete. *)
          ~choices:(fun ~self:_ ->
            [ { identifier = "recurse over customizable gate"
              ; prevs = [ tag ]
              ; main =
                  (fun _ ->
                    let proof =
                      exists (Typ.Internal.ref ()) ~request:(fun () ->
                          Requests.Proof )
                    in
                    { previous_proof_statements =
                        [ { public_input = ()
                          ; proof
                          ; proof_must_verify =
                              Boolean.true_ (* Special-case for genesis *)
                          }
                        ]
                    ; public_output = ()
                    ; auxiliary_output = ()
                    } )
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; custom_gate_type = None
              }
            ] )
          ()
      in
      let module Recursive_proof = (val recursive_proof) in
      let public_input, (), recursive_proof' =
        Async.Thread_safe.block_on_async_exn (fun () ->
            recursive_prove ~handler:(Requests.handler proof) () )
      in
      Or_error.ok_exn
        (Async.Thread_safe.block_on_async_exn (fun () ->
             Recursive_proof.verify [ (public_input, recursive_proof') ] ) )
  in
  test_prove ()

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

(* Step only tests *)
let () =
  if perform_step_tests then (
    (* Customised as ForeignFieldAdd gate; valid witness *)
    test ~step_only:true ~custom_gate_type:None ~valid_witness:true ;
    (* Customised as Conditional gate; valid witness *)
    (* Note: Requires Cache.Wrap.read_or_generate to have custom_gate_type passed to it *)
    (* test ~step_only:true ~custom_gate_type:conditional_gate ~valid_witness:true ; *)

    (* Customised as ForeignFieldAdd gate; invalid witness *)
    let test_failed =
      try
        let _cs =
          test ~step_only:true ~custom_gate_type:None ~valid_witness:false
        in
        false
      with _ -> true
    in
    assert test_failed ;

    (* Customised as Conditional gate; invalid witness *)
    (* let test_failed =
      try
        let _cs =
          test ~step_only:true ~custom_gate_type:conditional_gate
            ~valid_witness:false
        in
        false
      with _ -> true
    in
    assert test_failed ) *)
    )

(* Recursive tests *)
let () =
  if perform_recursive_tests then (
    (* Customised as ForeignFieldAdd gate; valid witness *)
    test ~step_only:false ~custom_gate_type:None ~valid_witness:true ;

    (* Customised as Conditional gate; valid witness *)
    test ~step_only:false ~custom_gate_type:conditional_gate ~valid_witness:true ;

    (* Customised as ForeignFieldAdd gate; invalid witness *)
    let test_failed =
      try
        let _cs =
          test ~step_only:false ~custom_gate_type:None ~valid_witness:false
        in
        false
      with _ -> true
    in
    assert test_failed ;

    (* Customised as Conditional gate; invalid witness *)
    let test_failed =
      try
        let _cs =
          test ~step_only:false ~custom_gate_type:conditional_gate
            ~valid_witness:false
        in
        false
      with _ -> true
    in
    assert test_failed ) ;
  ()

let () =
  if perform_step_choices_test then
    (* Test multiple step choices assertion *)
    let compile_failed =
      try
        let _test_multiple_step_choices =
          let ( _tag
              , _cache_handle
              , _proof
              , Pickles.Provers.[ _prove_a; _prove_b ] ) =
            Pickles.compile
              ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
              ~auxiliary_typ:Typ.unit
              ~branches:(module Nat.N2)
              ~max_proofs_verified:(module Nat.N0)
              ~name:"customizable gate"
              ~constraint_constants
                (* TODO(mrmr1993): This was misguided.. Delete. *)
              ~choices:(fun ~self:_ ->
                [ { identifier = "customizable gate"
                  ; prevs = []
                  ; main =
                      (fun _ ->
                        create_customisable_circuit ~custom_gate_type:None
                          ~valid_witness:true ;

                        { previous_proof_statements = []
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                  ; feature_flags =
                      Pickles_types.Plonk_types.Features.
                        { none_bool with foreign_field_add = true }
                  ; custom_gate_type = None
                  }
                ; { identifier = "customizable gate (choice 2)"
                  ; prevs = []
                  ; main =
                      (fun _ ->
                        create_customisable_circuit
                          ~custom_gate_type:conditional_gate ~valid_witness:true ;

                        { previous_proof_statements = []
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                  ; feature_flags =
                      Pickles_types.Plonk_types.Features.
                        { none_bool with foreign_field_add = true }
                  ; custom_gate_type = conditional_gate
                  }
                ] )
              ()
          in
          ()
        in

        false
      with _ -> true
    in
    assert compile_failed
