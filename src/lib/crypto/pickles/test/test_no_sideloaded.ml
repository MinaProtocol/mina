(* Testing
   -------

   Component: Pickles
   Subject: Test no sideloaded
   Invocation: \
    dune exec src/lib/pickles/test/test_no_sideloaded.exe
*)

module SC = Pickles.Scalar_challenge

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Core_kernel.Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

(* Currently, a circuit must have at least 1 of every type of constraint. *)
let dummy_constraints () =
  Impl.(
    let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
    let g =
      exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
          Pickles.Backend.Tick.Inner_curve.(to_affine_exn one) )
    in
    ignore
      ( SC.to_field_checked'
          (module Impl)
          ~num_bits:16
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t * Field.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t ))

module No_recursion = struct
  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N0)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    dummy_constraints () ;
                    Field.Assert.equal self Field.zero ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements = []
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let (), (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    (Field.Constant.zero, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

module No_recursion_return = struct
  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Output Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N0)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun _ ->
                    dummy_constraints () ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements = []
                      ; public_output = Field.zero
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let res, (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () -> step ()) )
    in
    assert (Field.Constant.(equal zero) res) ;
    (res, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input : Field.Constant.t Snarky_backendless.Request.t
    | Proof : Pickles_types.Nat.N1.n Proof.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N1)
          ~name:"blockchain-snark"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; prevs = [ self ]
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    let prev =
                      exists Field.typ ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                    in
                    let is_base_case = Field.equal Field.zero self in
                    let proof_must_verify = Boolean.not is_base_case in
                    let self_correct = Field.(equal (one + prev) self) in
                    Boolean.Assert.any [ self_correct; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = prev; proof; proof_must_verify } ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let s_neg_one = Field.Constant.(negate one) in
    let b_neg_one : Pickles_types.Nat.N1.n Pickles.Proof.t =
      Pickles.Proof.dummy Pickles_types.Nat.N1.n Pickles_types.Nat.N1.n
        ~domain_log2:14
    in
    let (), (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler s_neg_one b_neg_one) Field.Constant.zero ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    let (), (), b1 =
      Common.time "b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler Field.Constant.zero b0) Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
    (Field.Constant.one, b1)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

module Tree_proof = struct
  type _ Snarky_backendless.Request.t +=
    | No_recursion_input : Field.Constant.t Snarky_backendless.Request.t
    | No_recursion_proof :
        Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Recursive_input : Field.Constant.t Snarky_backendless.Request.t
    | Recursive_proof :
        Pickles_types.Nat.N2.n Proof.t Snarky_backendless.Request.t

  let handler
      ((no_recursion_input, no_recursion_proof) : Field.Constant.t * _ Proof.t)
      ((recursion_input, recursion_proof) : Field.Constant.t * _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | No_recursion_input ->
        respond (Provide no_recursion_input)
    | No_recursion_proof ->
        respond (Provide no_recursion_proof)
    | Recursive_input ->
        respond (Provide recursion_input)
    | Recursive_proof ->
        respond (Provide recursion_proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~override_wrap_domain:Pickles_base.Proofs_verified.N1
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N2)
          ~name:"blockchain-snark"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ No_recursion.tag; self ]
              ; main =
                  (fun { public_input = self } ->
                    let no_recursive_input =
                      exists Field.typ ~request:(fun () -> No_recursion_input)
                    in
                    let no_recursive_proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          No_recursion_proof )
                    in
                    let prev =
                      exists Field.typ ~request:(fun () -> Recursive_input)
                    in
                    let prev_proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Recursive_proof )
                    in
                    let is_base_case = Field.equal Field.zero self in
                    let proof_must_verify = Boolean.not is_base_case in
                    let self_correct = Field.(equal (one + prev) self) in
                    Boolean.Assert.any [ self_correct; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = no_recursive_input
                            ; proof = no_recursive_proof
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = prev
                            ; proof = prev_proof
                            ; proof_must_verify
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example1, example2 =
    let s_neg_one = Field.Constant.(negate one) in
    let b_neg_one : Pickles_types.Nat.N2.n Pickles.Proof.t =
      Pickles.Proof.dummy Pickles_types.Nat.N2.n Pickles_types.Nat.N2.n
        ~domain_log2:15
    in
    let (), (), b0 =
      Common.time "tree b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step
                ~handler:(handler No_recursion.example (s_neg_one, b_neg_one))
                Field.Constant.zero ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    let (), (), b1 =
      Common.time "tree b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step
                ~handler:
                  (handler No_recursion.example (Field.Constant.zero, b0))
                Field.Constant.one ) )
    in
    ((Field.Constant.zero, b0), (Field.Constant.one, b1))

  let examples = [ example1; example2 ]

  let test_verify_promise () =
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise examples))
end

module Tree_proof_return = struct
  type _ Snarky_backendless.Request.t +=
    | Is_base_case : bool Snarky_backendless.Request.t
    | No_recursion_input : Field.Constant.t Snarky_backendless.Request.t
    | No_recursion_proof :
        Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Recursive_input : Field.Constant.t Snarky_backendless.Request.t
    | Recursive_proof :
        Pickles_types.Nat.N2.n Proof.t Snarky_backendless.Request.t

  let handler (is_base_case : bool)
      ((no_recursion_input, no_recursion_proof) : Field.Constant.t * _ Proof.t)
      ((recursion_input, recursion_proof) : Field.Constant.t * _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Is_base_case ->
        respond (Provide is_base_case)
    | No_recursion_input ->
        respond (Provide no_recursion_input)
    | No_recursion_proof ->
        respond (Provide no_recursion_proof)
    | Recursive_input ->
        respond (Provide recursion_input)
    | Recursive_proof ->
        respond (Provide recursion_proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Output Field.typ)
          ~override_wrap_domain:Pickles_base.Proofs_verified.N1
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N2)
          ~name:"blockchain-snark"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ No_recursion_return.tag; self ]
              ; main =
                  (fun { public_input = () } ->
                    let no_recursive_input =
                      exists Field.typ ~request:(fun () -> No_recursion_input)
                    in
                    let no_recursive_proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          No_recursion_proof )
                    in
                    let prev =
                      exists Field.typ ~request:(fun () -> Recursive_input)
                    in
                    let prev_proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Recursive_proof )
                    in
                    let is_base_case =
                      exists Boolean.typ ~request:(fun () -> Is_base_case)
                    in
                    let proof_must_verify = Boolean.not is_base_case in
                    let self =
                      Field.(if_ is_base_case ~then_:zero ~else_:(one + prev))
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = no_recursive_input
                            ; proof = no_recursive_proof
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = prev
                            ; proof = prev_proof
                            ; proof_must_verify
                            }
                          ]
                      ; public_output = self
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example1, example2 =
    let s_neg_one = Field.Constant.(negate one) in
    let b_neg_one : Pickles_types.Nat.N2.n Pickles.Proof.t =
      Pickles.Proof.dummy Pickles_types.Nat.N2.n Pickles_types.Nat.N2.n
        ~domain_log2:15
    in
    let s0, (), b0 =
      Common.time "tree b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step
                ~handler:
                  (handler true No_recursion_return.example
                     (s_neg_one, b_neg_one) )
                () ) )
    in
    assert (Field.Constant.(equal zero) s0) ;
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s0, b0) ])) ;
    let s1, (), b1 =
      Common.time "tree b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step
                ~handler:(handler false No_recursion_return.example (s0, b0))
                () ) )
    in
    assert (Field.Constant.(equal one) s1) ;
    ((s0, b0), (s1, b1))

  let examples = [ example1; example2 ]

  let test_verify () =
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise examples))
end

module Add_one_return = struct
  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise ()
          ~public_input:(Input_and_output (Field.typ, Field.typ))
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N0)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = []
              ; main =
                  (fun { public_input = x } ->
                    dummy_constraints () ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements = []
                      ; public_output = Field.(add one) x
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let input = Field.Constant.of_int 42 in
    let res, (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () -> step input) )
    in
    assert (Field.Constant.(equal (of_int 43)) res) ;
    ((input, res), b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

module Auxiliary_return = struct
  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise ()
          ~public_input:(Input_and_output (Field.typ, Field.typ))
          ~auxiliary_typ:Field.typ
          ~max_proofs_verified:(module Pickles_types.Nat.N0)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = []
              ; main =
                  (fun { public_input = input } ->
                    dummy_constraints () ;
                    let sponge =
                      Step_main_inputs.Sponge.create
                        Step_main_inputs.sponge_params
                    in
                    let blinding_value =
                      exists Field.typ ~compute:Field.Constant.random
                    in
                    Step_main_inputs.Sponge.absorb sponge (`Field input) ;
                    Step_main_inputs.Sponge.absorb sponge (`Field blinding_value) ;
                    let result = Step_main_inputs.Sponge.squeeze sponge in
                    Promise.return
                      { Inductive_rule.previous_proof_statements = []
                      ; public_output = result
                      ; auxiliary_output = blinding_value
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let input = Field.Constant.of_int 42 in
    let result, blinding_value, b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () -> step input) )
    in
    let sponge = Tick_field_sponge.Field.create Tick_field_sponge.params in
    Tick_field_sponge.Field.absorb sponge input ;
    Tick_field_sponge.Field.absorb sponge blinding_value ;
    let result' = Tick_field_sponge.Field.squeeze sponge in
    assert (Field.Constant.equal result result') ;
    ((input, result), b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

let () =
  let open Alcotest in
  run "Pickles no sideloaded"
    [ ("No recursion", [ test_case "verify" `Quick No_recursion.test_verify ])
    ; ( "No recursion return"
      , [ test_case "verify" `Quick No_recursion_return.test_verify ] )
    ; ("Simple chain", [ test_case "verify" `Quick Simple_chain.test_verify ])
    ; ( "Tree proof"
      , [ test_case "verify" `Quick Tree_proof.test_verify_promise ] )
    ; ( "Tree proof return"
      , [ test_case "verify" `Quick Tree_proof_return.test_verify ] )
    ; ( "Add one return"
      , [ test_case "verify" `Quick Add_one_return.test_verify ] )
    ; ( "Auxiliary return"
      , [ test_case "verify" `Quick Auxiliary_return.test_verify ] )
    ]
