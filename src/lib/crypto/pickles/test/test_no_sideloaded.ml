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

(* Probe: exercise [compile] with a maximum of 3 proofs verified, to start
   unwinding the hard-coded maximum of 2. The branch verifies three
   (base-case) [No_recursion] proofs. *)
module Tree_proof_n3 = struct
  type _ Snarky_backendless.Request.t +=
    | Proof0 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Proof1 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Proof2 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t

  let handler (p0 : _ Proof.t) (p1 : _ Proof.t) (p2 : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Proof0 ->
        respond (Provide p0)
    | Proof1 ->
        respond (Provide p1)
    | Proof2 ->
        respond (Provide p2)
    | _ ->
        respond Unhandled

  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N3)
          ~name:"tree-proof-n3"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ No_recursion.tag; No_recursion.tag; No_recursion.tag ]
              ; main =
                  (fun { public_input = _self } ->
                    dummy_constraints () ;
                    let proof0 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof0)
                    in
                    let proof1 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof1)
                    in
                    let proof2 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof2)
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof = proof0
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof = proof1
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof = proof2
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let _, no_proof = No_recursion.example in
    let (), (), b0 =
      Common.time "tree n3 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step
                ~handler:(handler no_proof no_proof no_proof)
                Field.Constant.zero ) )
    in
    (Field.Constant.zero, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

(* Extension probe: a circuit with [max_proofs_verified = 1] that verifies the
   [max_proofs_verified = 3] proof produced above. This exercises consuming a
   wider proof (whose branch_data mask is 3 bits) inside a narrower circuit. *)
module Verify_n3 = struct
  type _ Snarky_backendless.Request.t +=
    | N3_proof : Pickles_types.Nat.N3.n Proof.t Snarky_backendless.Request.t

  let handler (proof : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | N3_proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N1)
          ~name:"verify-n3"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ Tree_proof_n3.tag ]
              ; main =
                  (fun { public_input = _self } ->
                    dummy_constraints () ;
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () -> N3_proof)
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let _n3_input, n3_proof = Tree_proof_n3.example in
    let (), (), b0 =
      Common.time "verify n3 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler n3_proof) Field.Constant.zero ) )
    in
    (Field.Constant.zero, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

(* Self-recursion probe: a max_proofs_verified = 3 rule that verifies three
   [self] proofs. Exercises the base case (proof_must_verify = false) and a
   recursive invocation (proof_must_verify = true). *)
module Self_recursion_3 = struct
  type _ Snarky_backendless.Request.t +=
    | P0 : Pickles_types.Nat.N3.n Proof.t Snarky_backendless.Request.t
    | P1 : Pickles_types.Nat.N3.n Proof.t Snarky_backendless.Request.t
    | P2 : Pickles_types.Nat.N3.n Proof.t Snarky_backendless.Request.t

  let handler (p0 : _ Proof.t) (p1 : _ Proof.t) (p2 : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | P0 ->
        respond (Provide p0)
    | P1 ->
        respond (Provide p1)
    | P2 ->
        respond (Provide p2)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N3)
          ~name:"self-recursion-3"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ self; self; self ]
              ; main =
                  (fun { public_input = self_input } ->
                    dummy_constraints () ;
                    let is_base_case = Field.equal Field.zero self_input in
                    let proof_must_verify = Boolean.not is_base_case in
                    let p0 =
                      exists (Typ.prover_value ()) ~request:(fun () -> P0)
                    in
                    let p1 =
                      exists (Typ.prover_value ()) ~request:(fun () -> P1)
                    in
                    let p2 =
                      exists (Typ.prover_value ()) ~request:(fun () -> P2)
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof = p0
                            ; proof_must_verify
                            }
                          ; { public_input = Field.zero
                            ; proof = p1
                            ; proof_must_verify
                            }
                          ; { public_input = Field.zero
                            ; proof = p2
                            ; proof_must_verify
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let dummy : Pickles_types.Nat.N3.n Pickles.Proof.t =
      Pickles.Proof.dummy Pickles_types.Nat.N3.n Pickles_types.Nat.N3.n
        ~domain_log2:16
    in
    (* Base case: self = 0, proofs are dummies, proof_must_verify = false. *)
    let (), (), b0 =
      Common.time "self-rec-3 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler dummy dummy dummy) Field.Constant.zero ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    (* Recursive case: self = 1, verifies three copies of the base proof. *)
    let (), (), b1 =
      Common.time "self-rec-3 b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler b0 b0 b0) Field.Constant.one ) )
    in
    (Field.Constant.one, b1)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

(* A clean width-2 proof system (two [No_recursion] proofs, no
   override_wrap_domain) usable as the narrow prev in the mixed-width test. *)
module Tree_proof_n2 = struct
  type _ Snarky_backendless.Request.t +=
    | R0 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | R1 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t

  let handler (p0 : _ Proof.t) (p1 : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | R0 ->
        respond (Provide p0)
    | R1 ->
        respond (Provide p1)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~override_wrap_domain:Pickles_base.Proofs_verified.N1
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N2)
          ~name:"tree-proof-n2"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ No_recursion.tag; No_recursion.tag ]
              ; main =
                  (fun { public_input = _self } ->
                    dummy_constraints () ;
                    let p0 =
                      exists (Typ.prover_value ()) ~request:(fun () -> R0)
                    in
                    let p1 =
                      exists (Typ.prover_value ()) ~request:(fun () -> R1)
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof = p0
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof = p1
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let _, no_proof = No_recursion.example in
    let (), (), b0 =
      Common.time "tree n2 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler no_proof no_proof) Field.Constant.zero ) )
    in
    (Field.Constant.zero, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

(* Width-4 probe: confirm 3 isn't a special case by verifying four
   (base-case) [No_recursion] proofs. *)
module Tree_proof_n4 = struct
  type _ Snarky_backendless.Request.t +=
    | Q0 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Q1 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Q2 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t
    | Q3 : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t

  let handler (p0 : _ Proof.t) (p1 : _ Proof.t) (p2 : _ Proof.t)
      (p3 : _ Proof.t) (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Q0 ->
        respond (Provide p0)
    | Q1 ->
        respond (Provide p1)
    | Q2 ->
        respond (Provide p2)
    | Q3 ->
        respond (Provide p3)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N4)
          ~name:"tree-proof-n4"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs =
                  [ No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ]
              ; main =
                  (fun { public_input = _self } ->
                    dummy_constraints () ;
                    let p0 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Q0)
                    in
                    let p1 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Q1)
                    in
                    let p2 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Q2)
                    in
                    let p3 =
                      exists (Typ.prover_value ()) ~request:(fun () -> Q3)
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof = p0
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof = p1
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof = p2
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof = p3
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let _, no_proof = No_recursion.example in
    let (), (), b0 =
      Common.time "tree n4 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step
                ~handler:(handler no_proof no_proof no_proof no_proof)
                Field.Constant.zero ) )
    in
    (Field.Constant.zero, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

(* The consistency guard must reject a multi-branch circuit whose branches
   verify prevs of different widths (one width-3, one narrower) in the same
   slot, rather than silently producing an unsatisfiable circuit. *)
module Mixed_widths_rejected = struct
  type _ Snarky_backendless.Request.t +=
    | Wide : Pickles_types.Nat.N3.n Proof.t Snarky_backendless.Request.t
    | Narrow : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t

  let attempt () =
    let _tag, _, _p, Provers.[ _; _ ] =
      Common.time "compile mixed-rejected" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~max_proofs_verified:(module Pickles_types.Nat.N1)
            ~name:"mixed-widths-rejected"
            ~choices:(fun ~self:_ ->
              [ { identifier = "wide"
                ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
                ; prevs = [ Tree_proof_n3.tag ]
                ; main =
                    (fun { public_input = _self } ->
                      dummy_constraints () ;
                      let proof =
                        exists (Typ.prover_value ()) ~request:(fun () -> Wide)
                      in
                      Promise.return
                        { Inductive_rule.previous_proof_statements =
                            [ { public_input = Field.zero
                              ; proof
                              ; proof_must_verify = Boolean.true_
                              }
                            ]
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                }
              ; { identifier = "narrow"
                ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
                ; prevs = [ No_recursion.tag ]
                ; main =
                    (fun { public_input = _self } ->
                      dummy_constraints () ;
                      let proof =
                        exists (Typ.prover_value ()) ~request:(fun () ->
                            Narrow )
                      in
                      Promise.return
                        { Inductive_rule.previous_proof_statements =
                            [ { public_input = Field.zero
                              ; proof
                              ; proof_must_verify = Boolean.true_
                              }
                            ]
                        ; public_output = ()
                        ; auxiliary_output = ()
                        } )
                }
              ] ) )
    in
    ()

  let test_rejected () =
    match attempt () with
    | () ->
        failwith
          "expected the consistency guard to reject the mixed-width \
           configuration"
    | exception Failure msg ->
        assert (
          Core_kernel.String.is_substring msg ~substring:"proofs-verified width" )
end

(* Width-5 probe: verify 5 base proofs. *)
module Tree_proof_n5 = struct
  type _ Snarky_backendless.Request.t +=
    | Proof_req : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t

  let handler (proof : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Proof_req ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N5)
          ~name:"tree-proof-n5"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs =
                  [ No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ]
              ; main =
                  (fun { public_input = _self } ->
                    dummy_constraints () ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let _, no_proof = No_recursion.example in
    let (), (), b0 =
      Common.time "tree n5 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler no_proof) Field.Constant.zero ) )
    in
    (Field.Constant.zero, b0)

  let test_verify () =
    let input, proof = example in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (input, proof) ] ) )
end

(* Width-6 probe: verify 6 base proofs. *)
module Tree_proof_n6 = struct
  type _ Snarky_backendless.Request.t +=
    | Proof_req : Pickles_types.Nat.N0.n Proof.t Snarky_backendless.Request.t

  let handler (proof : _ Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Proof_req ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N6)
          ~name:"tree-proof-n6"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs =
                  [ No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ; No_recursion.tag
                  ]
              ; main =
                  (fun { public_input = _self } ->
                    dummy_constraints () ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ; { public_input = Field.zero
                            ; proof =
                                exists (Typ.prover_value ()) ~request:(fun () ->
                                    Proof_req )
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let _, no_proof = No_recursion.example in
    let (), (), b0 =
      Common.time "tree n6 b0" (fun () ->
          Promise.block_on_async_exn (fun () ->
              step ~handler:(handler no_proof) Field.Constant.zero ) )
    in
    (Field.Constant.zero, b0)

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
    ; ("Tree proof N3", [ test_case "verify" `Quick Tree_proof_n3.test_verify ])
    ; ("Verify N3", [ test_case "verify" `Quick Verify_n3.test_verify ])
    ; ("Tree proof N2", [ test_case "verify" `Quick Tree_proof_n2.test_verify ])
    ; ( "Self recursion 3"
      , [ test_case "verify" `Quick Self_recursion_3.test_verify ] )
    ; ("Tree proof N4", [ test_case "verify" `Quick Tree_proof_n4.test_verify ])
    ; ( "Mixed widths rejected"
      , [ test_case "rejected" `Quick Mixed_widths_rejected.test_rejected ] )
    ; ("Tree proof N5", [ test_case "verify" `Quick Tree_proof_n5.test_verify ])
    ; ("Tree proof N6", [ test_case "verify" `Quick Tree_proof_n6.test_verify ])
    ]
