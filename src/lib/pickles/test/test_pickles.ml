open Pickles_types
open Pickles
open Backend
module Proof0 = Proof

let dummy_constants =
  let open Snark_keys_header.Constraint_constants in
  { sub_windows_per_window = 0
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

module Tests = struct
  let l = ref []

  let add ~name ~f ~quickness = l := Alcotest.test_case name quickness f :: !l

  let add_slow = add ~quickness:`Slow

  let add_quick = add ~quickness:`Quick
end

module Test1 = struct
  let () = Tock.Keypair.set_urs_info []

  let () = Tick.Keypair.set_urs_info []

  let () = Backtrace.elide := false

  open Impls.Step

  let () = Snarky_backendless.Snark0.set_eval_constraints true

  (* Currently, a circuit must have at least 1 of every type of constraint. *)
  let dummy_constraints () =
    Impl.(
      let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
      let g =
        exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
            Tick.Inner_curve.(to_affine_exn one) )
      in
      ignore
        ( Scalar_challenge.to_field_checked'
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
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N0)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
                }
              ] ) )

    module Proof = (val p)

    let example () =
      let (), (), b0 =
        Common.time "b0" (fun () ->
            Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
      (Field.Constant.zero, b0)

    let example_input, example_proof = example ()
  end

  module No_recursion_return = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Output Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N0)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun _ ->
                      dummy_constraints () ;
                      { previous_proof_statements = []
                      ; public_output = Field.zero
                      ; auxiliary_output = ()
                      } )
                }
              ] ) )

    module Proof = (val p)

    let example =
      lazy
        (let res, (), b0 =
           Common.time "b0" (fun () ->
               Promise.block_on_async_exn (fun () -> step ()) )
         in
         assert (Field.Constant.(equal zero) res) ;
         Or_error.ok_exn
           (Promise.block_on_async_exn (fun () ->
                Proof.verify_promise [ (res, b0) ] ) ) ;
         (res, b0) )

    let () =
      Tests.add_slow ~name:"no recursion return" ~f:(fun () ->
          let _r, _b = Lazy.force example in
          () )
  end

  module Simple_chain = struct
    type _ Snarky_backendless.Request.t +=
      | Prev_input : Field.Constant.t Snarky_backendless.Request.t
      | Proof : (Nat.N1.n, Nat.N1.n) Proof.t Snarky_backendless.Request.t

    let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Prev_input ->
          respond (Provide prev_input)
      | Proof ->
          respond (Provide proof)
      | _ ->
          respond Unhandled

    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N1)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self ->
              [ { identifier = "main"
                ; prevs = [ self ]
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      let prev =
                        exists Field.typ ~request:(fun () -> Prev_input)
                      in
                      let proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () -> Proof)
                      in
                      let is_base_case = Field.equal Field.zero self in
                      let proof_must_verify = Boolean.not is_base_case in
                      let self_correct = Field.(equal (one + prev) self) in
                      Boolean.Assert.any [ self_correct; is_base_case ] ;
                      { previous_proof_statements =
                          [ { public_input = prev; proof; proof_must_verify } ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
                }
              ] ) )

    module Proof = (val p)

    let example () =
      let s_neg_one = Field.Constant.(negate one) in
      let b_neg_one : (Nat.N1.n, Nat.N1.n) Proof0.t =
        Proof0.dummy Nat.N1.n Nat.N1.n Nat.N1.n ~domain_log2:14
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
                step
                  ~handler:(handler Field.Constant.zero b0)
                  Field.Constant.one ) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
      (Field.Constant.one, b1)

    let () =
      Tests.add_slow ~name:"simple chain" ~f:(fun () ->
          let _field, _proof = example () in
          () )
  end

  module Tree_proof = struct
    type _ Snarky_backendless.Request.t +=
      | No_recursion_input : Field.Constant.t Snarky_backendless.Request.t
      | No_recursion_proof :
          (Nat.N0.n, Nat.N0.n) Proof.t Snarky_backendless.Request.t
      | Recursive_input : Field.Constant.t Snarky_backendless.Request.t
      | Recursive_proof :
          (Nat.N2.n, Nat.N2.n) Proof.t Snarky_backendless.Request.t

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

    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N2)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self ->
              [ { identifier = "main"
                ; feature_flags = Plonk_types.Features.none_bool
                ; prevs = [ No_recursion.tag; self ]
                ; main =
                    (fun { public_input = self } ->
                      let no_recursive_input =
                        exists Field.typ ~request:(fun () ->
                            No_recursion_input )
                      in
                      let no_recursive_proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () ->
                            No_recursion_proof )
                      in
                      let prev =
                        exists Field.typ ~request:(fun () -> Recursive_input)
                      in
                      let prev_proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () ->
                            Recursive_proof )
                      in
                      let is_base_case = Field.equal Field.zero self in
                      let proof_must_verify = Boolean.not is_base_case in
                      let self_correct = Field.(equal (one + prev) self) in
                      Boolean.Assert.any [ self_correct; is_base_case ] ;
                      { previous_proof_statements =
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
      let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
        Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
      in
      let (), (), b0 =
        Common.time "tree b0" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler (No_recursion.example ()) (s_neg_one, b_neg_one))
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
                    (handler (No_recursion.example ()) (Field.Constant.zero, b0))
                  Field.Constant.one ) )
      in
      ((Field.Constant.zero, b0), (Field.Constant.one, b1))

    let examples = [ example1; example2 ]

    let example1_input, example_proof = example1

    let example2_input, example2_proof = example2

    let () =
      Tests.add_slow ~name:"trees proof" ~f:(fun () ->
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise examples ) ) )
  end

  module Tree_proof_return = struct
    type _ Snarky_backendless.Request.t +=
      | Is_base_case : bool Snarky_backendless.Request.t
      | No_recursion_input : Field.Constant.t Snarky_backendless.Request.t
      | No_recursion_proof :
          (Nat.N0.n, Nat.N0.n) Proof.t Snarky_backendless.Request.t
      | Recursive_input : Field.Constant.t Snarky_backendless.Request.t
      | Recursive_proof :
          (Nat.N2.n, Nat.N2.n) Proof.t Snarky_backendless.Request.t

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

    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Output Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N2)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self ->
              [ { identifier = "main"
                ; feature_flags = Plonk_types.Features.none_bool
                ; prevs = [ No_recursion_return.tag; self ]
                ; main =
                    (fun { public_input = () } ->
                      let no_recursive_input =
                        exists Field.typ ~request:(fun () ->
                            No_recursion_input )
                      in
                      let no_recursive_proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () ->
                            No_recursion_proof )
                      in
                      let prev =
                        exists Field.typ ~request:(fun () -> Recursive_input)
                      in
                      let prev_proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () ->
                            Recursive_proof )
                      in
                      let is_base_case =
                        exists Boolean.typ ~request:(fun () -> Is_base_case)
                      in
                      let proof_must_verify = Boolean.not is_base_case in
                      let self =
                        Field.(if_ is_base_case ~then_:zero ~else_:(one + prev))
                      in
                      { previous_proof_statements =
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
      let b_neg_one : (Nat.N2.n, Nat.N2.n) Proof0.t =
        Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
      in
      let s0, (), b0 =
        Common.time "tree b0" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler true
                       (Lazy.force No_recursion_return.example)
                       (s_neg_one, b_neg_one) )
                  () ) )
      in
      assert (Field.Constant.(equal zero) s0) ;
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (s0, b0) ] ) ) ;
      let s1, (), b1 =
        Common.time "tree b1" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler false
                       (Lazy.force No_recursion_return.example)
                       (s0, b0) )
                  () ) )
      in
      assert (Field.Constant.(equal one) s1) ;
      ((s0, b0), (s1, b1))

    let examples = [ example1; example2 ]

    let example1_input, example1_proof = example1

    let example2_input, example2_proof = example2

    let () =
      Tests.add_slow ~name:"tree_proof return" ~f:(fun () ->
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise examples ) ) )
  end

  module Add_one_return = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise ()
            ~public_input:(Input_and_output (Field.typ, Field.typ))
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N0)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; feature_flags = Plonk_types.Features.none_bool
                ; prevs = []
                ; main =
                    (fun { public_input = x } ->
                      dummy_constraints () ;
                      { previous_proof_statements = []
                      ; public_output = Field.(add one) x
                      ; auxiliary_output = ()
                      } )
                }
              ] ) )

    module Proof = (val p)

    let example () =
      let input = Field.Constant.of_int 42 in
      let res, (), b0 =
        Common.time "b0" (fun () ->
            Promise.block_on_async_exn (fun () -> step input) )
      in
      assert (Field.Constant.(equal (of_int 43)) res) ;
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ ((input, res), b0) ] ) ) ;
      ((input, res), b0)

    (* let example_input, example_proof = example *)

    let () =
      Tests.add_slow ~name:"add one return" ~f:(fun () ->
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ example () ] ) ) )
  end

  module Auxiliary_return = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise ()
            ~public_input:(Input_and_output (Field.typ, Field.typ))
            ~auxiliary_typ:Field.typ
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N0)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; feature_flags = Plonk_types.Features.none_bool
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
                      Step_main_inputs.Sponge.absorb sponge
                        (`Field blinding_value) ;
                      let result = Step_main_inputs.Sponge.squeeze sponge in
                      { previous_proof_statements = []
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
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ ((input, result), b0) ] ) ) ;
      ((input, result), b0)

    let example_input, example_proof = example
  end
end

module Domain_too_small = struct
  open Impls.Step

  (* Currently, a circuit must have at least 1 of every type of constraint. *)
  let dummy_constraints () =
    Impl.(
      let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
      let g =
        exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
            Tick.Inner_curve.(to_affine_exn one) )
      in
      ignore
        ( Scalar_challenge.to_field_checked'
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
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N0)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
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

    let example_input, example_proof = example
  end

  module Fake_1_recursion = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N1)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
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

    let example_input, example_proof = example
  end

  module Fake_2_recursion = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N2)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
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

    let example_input, example_proof = example
  end

  module Simple_chain = struct
    type _ Snarky_backendless.Request.t +=
      | Prev_input : Field.Constant.t Snarky_backendless.Request.t
      | Proof : Side_loaded.Proof.t Snarky_backendless.Request.t
      | Verifier_index :
          Side_loaded.Verification_key.t Snarky_backendless.Request.t

    let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
        (verifier_index : Side_loaded.Verification_key.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Prev_input ->
          respond (Provide prev_input)
      | Proof ->
          respond (Provide proof)
      | Verifier_index ->
          respond (Provide verifier_index)
      | _ ->
          respond Unhandled

    let side_loaded_tag =
      Side_loaded.create ~name:"foo"
        ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
        ~feature_flags:Plonk_types.Features.none ~typ:Field.typ

    let _tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N1)
            ~name:"blockchain-snark" ~constraint_constants:dummy_constants
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = [ side_loaded_tag ]
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      let prev =
                        exists Field.typ ~request:(fun () -> Prev_input)
                      in
                      let proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () -> Proof)
                      in
                      let vk =
                        exists (Typ.Internal.ref ()) ~request:(fun () ->
                            Verifier_index )
                      in
                      as_prover (fun () ->
                          let vk = As_prover.Ref.get vk in
                          Side_loaded.in_prover side_loaded_tag vk ) ;
                      let vk =
                        exists Side_loaded.Verification_key.typ
                          ~compute:(fun () -> As_prover.Ref.get vk)
                      in
                      Side_loaded.in_circuit side_loaded_tag vk ;
                      let is_base_case = Field.equal Field.zero self in
                      let self_correct = Field.(equal (one + prev) self) in
                      Boolean.Assert.any [ self_correct; is_base_case ] ;
                      { previous_proof_statements =
                          [ { public_input = prev
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

    let _example1 =
      let (), (), b1 =
        Common.time "b1" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler No_recursion.example_input
                       (Side_loaded.Proof.of_proof No_recursion.example_proof)
                       (Side_loaded.Verification_key.of_compiled
                          No_recursion.tag ) )
                  Field.Constant.one ) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
      (Field.Constant.one, b1)

    let _example2 =
      let (), (), b2 =
        Common.time "b2" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler Fake_1_recursion.example_input
                       (Side_loaded.Proof.of_proof
                          Fake_1_recursion.example_proof )
                       (Side_loaded.Verification_key.of_compiled
                          Fake_1_recursion.tag ) )
                  Field.Constant.one ) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.one, b2) ] ) ) ;
      (Field.Constant.one, b2)

    let _example3 =
      let (), (), b3 =
        Common.time "b3" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler Fake_2_recursion.example_input
                       (Side_loaded.Proof.of_proof
                          Fake_2_recursion.example_proof )
                       (Side_loaded.Verification_key.of_compiled
                          Fake_2_recursion.tag ) )
                  Field.Constant.one ) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.one, b3) ] ) ) ;
      (Field.Constant.one, b3)
  end
end

(* module Test_uncorrelated_deferred_b = struct
 *   let () = Backtrace.elide := false
 * 
 *   let () = Snarky_backendless.Snark0.set_eval_constraints true
 * 
 *   open Impls.Step
 * 
 *   module Statement = struct
 *     type t = unit
 * 
 *     let to_field_elements () = [||]
 *   end
 * 
 *   module A = Statement
 *   module A_value = Statement
 * 
 *   let typ = Typ.unit
 * 
 *   module Branches = Nat.N1
 *   module Max_proofs_verified = Nat.N2
 * 
 *   let override_wrap_main : _ Pickles__Compile.wrap_main_generic =
 *     { wrap_main =
 *         (fun _ _ _ _ _ _ _ ->
 *           let requests =
 *             (\* The requests that the logic in [Wrap.wrap] use to pass
 *                values into and out of the wrap proof circuit.
 *                Since these are unnecessary for the dummy circuit below, we
 *                generate them without using them.
 *             *\)
 *             Pickles__Requests.Wrap.create ()
 *           in
 *           (\* A replacement for the 'wrap' circuit, which makes no
 *              assertions about the statement that it receives as its first
 *              argument.
 *           *\)
 *           let wrap_main _ =
 *             let module SC' = Scalar_challenge in
 *             let open Impls.Wrap in
 *             let open Pickles__Wrap_main_inputs in
 *             let open Pickles__Wrap_main in
 *             (\* Create some variables to be used in constraints below. *\)
 *             let x =
 *               exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
 *             in
 *             let y =
 *               exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0)
 *             in
 *             let z =
 *               exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0)
 *             in
 *             (\* Every circuit must use at least 1 of each constraint; we
 *                use them here.
 *             *\)
 *             let () =
 *               let g = Inner_curve.one in
 *               let sponge = Sponge.create sponge_params in
 *               Sponge.absorb sponge x ;
 *               ignore (Sponge.squeeze_field sponge : Field.t) ;
 *               ignore
 *                 ( SC'.to_field_checked'
 *                     (module Impl)
 *                     ~num_bits:16
 *                     (Kimchi_backend_common.Scalar_challenge.create x)
 *                   : Field.t * Field.t * Field.t ) ;
 *               ignore
 *                 (Ops.scale_fast g ~num_bits:5 (Shifted_value x) : Inner_curve.t) ;
 *               ignore
 *                 ( Pickles__Wrap_verifier.Scalar_challenge.endo g ~num_bits:4
 *                     (Kimchi_backend_common.Scalar_challenge.create x)
 *                   : Field.t * Field.t )
 *             in
 *             (\* Pad the circuit so that its domain size matches the one
 *                that would have been used by the true wrap_main.
 *             *\)
 *             for i = 0 to 64000 do
 *               assert_r1cs x y z
 *             done
 *           in
 *           (requests, wrap_main) )
 *     ; tweak_statement =
 *         (fun stmt ->
 *           (\* Modify the statement to contain an invalid [b] value. *\)
 *           let b = Tick.Field.random () in
 *           let shift_value =
 *             Shifted_value.Type1.of_field
 *               (module Tick.Field)
 *               ~shift:Common.Shifts.tick1
 *           in
 *           { stmt with
 *             proof_state =
 *               { stmt.proof_state with
 *                 deferred_values =
 *                   { stmt.proof_state.deferred_values with b = shift_value b }
 *               }
 *           } )
 *     }
 * 
 *   let tag, _, p, Provers.[ step ] = assert false
 *     Pickles__Compile.compile_with_wrap_main_override_promise ()
 *       ~override_wrap_main ~public_input:(Input Typ.unit) ~auxiliary_typ:Typ.unit
 *       ~branches:(module Nat.N1)
 *       ~max_proofs_verified:(module Nat.N2)
 *       ~name:"blockchain-snark" ~constraint_constants:dummy_constants
 *       ~choices:(fun ~self ->
 *         [ { identifier = "main"
 *           ; prevs = [ self; self ]
 *           ; main =
 *               (fun { public_input = () } ->
 *                 let proof : (Nat.N2.n, Nat.N2.n) Proof.t As_prover.Ref.t =
 *                   As_prover.Ref.create (fun () ->
 *                       Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15 )
 *                 in
 *                 { previous_proof_statements =
 *                     [ { public_input = ()
 *                       ; proof
 *                       ; proof_must_verify = Boolean.false_
 *                       }
 *                     ; { public_input = ()
 *                       ; proof
 *                       ; proof_must_verify = Boolean.false_
 *                       }
 *                     ]
 *                 ; public_output = ()
 *                 ; auxiliary_output = ()
 *                 } )
 *           ; feature_flags = Plonk_types.Features.none_bool
 *           }
 *         ] )
 * 
 *   module Proof = (val p)
 * 
 *   let proof_with_stmt =
 *     let (), (), p = Promise.block_on_async_exn (fun () -> step ()) in
 *     ((), p)
 * 
 *   let () =
 *     Tests.add_slow ~name:"should not be able to verify invalid proof"
 *       ~f:(fun () ->
 *         assert (
 *           Or_error.is_error
 *           @@ Promise.block_on_async_exn (fun () ->
 *                  Proof.verify_promise [ proof_with_stmt ] ) ) )
 * 
 *   module Recurse_on_bad_proof = struct
 *     open Impls.Step
 * 
 *     let dummy_proof = Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
 * 
 *     type _ Snarky_backendless.Request.t +=
 *       | Proof : (Nat.N2.n, Nat.N2.n) Proof0.t Snarky_backendless.Request.t
 * 
 *     let handler (proof : _ Proof0.t)
 *         (Snarky_backendless.Request.With { request; respond }) =
 *       match request with
 *       | Proof ->
 *           respond (Provide proof)
 *       | _ ->
 *           respond Unhandled
 * 
 *     let tag, _, p, Provers.[ step ] =
 *       Common.time "compile" (fun () ->
 *           compile_promise () ~public_input:(Input Typ.unit)
 *             ~auxiliary_typ:Typ.unit
 *             ~branches:(module Nat.N1)
 *             ~max_proofs_verified:(module Nat.N2)
 *             ~name:"recurse-on-bad" ~constraint_constants:dummy_constants
 *             ~choices:(fun ~self:_ ->
 *               [ { identifier = "main"
 *                 ; feature_flags = Plonk_types.Features.none_bool
 *                 ; prevs = [ tag; tag ]
 *                 ; main =
 *                     (fun { public_input = () } ->
 *                       let proof =
 *                         exists (Typ.Internal.ref ()) ~request:(fun () -> Proof)
 *                       in
 *                       { previous_proof_statements =
 *                           [ { public_input = ()
 *                             ; proof
 *                             ; proof_must_verify = Boolean.true_
 *                             }
 *                           ; { public_input = ()
 *                             ; proof
 *                             ; proof_must_verify = Boolean.true_
 *                             }
 *                           ]
 *                       ; public_output = ()
 *                       ; auxiliary_output = ()
 *                       } )
 *                 }
 *               ] ) )
 * 
 *     module Proof = (val p)
 *   end
 * 
 *   let () =
 *     Tests.add_slow
 *       ~name:
 *         "should not be able to create a recursive proof from an invalid proof"
 *       ~f:(fun () ->
 *         assert (
 *           try
 *             let (), (), proof =
 *               Promise.block_on_async_exn (fun () ->
 *                   Recurse_on_bad_proof.step
 *                     ~handler:
 *                       (Recurse_on_bad_proof.handler (snd proof_with_stmt))
 *                     () )
 *             in
 *             Or_error.is_error
 *             @@ Promise.block_on_async_exn (fun () ->
 *                    Recurse_on_bad_proof.Proof.verify_promise [ ((), proof) ] )
 *           with _ -> true ) )
 * end *)

module Side_loaded_with_feature_flags = struct
  open Impls.Step

  (* Currently, a circuit must have at least 1 of every type of constraint. *)
  let dummy_constraints () =
    Impl.(
      let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
      let g =
        exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
            Tick.Inner_curve.(to_affine_exn one) )
      in
      ignore
        ( Scalar_challenge.to_field_checked'
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
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N0)
            ~name:"blockchain-snark"
            ~constraint_constants:
              (* Dummy values *)
              { sub_windows_per_window = 0
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
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
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

    let example_input, example_proof = example
  end

  module Fake_1_recursion = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N1)
            ~name:"blockchain-snark"
            ~constraint_constants:
              (* Dummy values *)
              { sub_windows_per_window = 0
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
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
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

    let example_input, example_proof = example
  end

  module Fake_2_recursion = struct
    let tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N2)
            ~name:"blockchain-snark"
            ~constraint_constants:
              (* Dummy values *)
              { sub_windows_per_window = 0
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
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = []
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      dummy_constraints () ;
                      Field.Assert.equal self Field.zero ;
                      { previous_proof_statements = []
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

    let example_input, example_proof = example
  end

  module Simple_chain = struct
    type _ Snarky_backendless.Request.t +=
      | Prev_input : Field.Constant.t Snarky_backendless.Request.t
      | Proof : Side_loaded.Proof.t Snarky_backendless.Request.t
      | Verifier_index :
          Side_loaded.Verification_key.t Snarky_backendless.Request.t

    let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
        (verifier_index : Side_loaded.Verification_key.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Prev_input ->
          respond (Provide prev_input)
      | Proof ->
          respond (Provide proof)
      | Verifier_index ->
          respond (Provide verifier_index)
      | _ ->
          respond Unhandled

    let maybe_features =
      Plonk_types.Features.(map none ~f:(fun _ -> Plonk_types.Opt.Flag.Maybe))

    let side_loaded_tag =
      Side_loaded.create ~name:"foo"
        ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
        ~feature_flags:maybe_features ~typ:Field.typ

    let _tag, _, p, Provers.[ step ] =
      Common.time "compile" (fun () ->
          compile_promise () ~public_input:(Input Field.typ)
            ~auxiliary_typ:Typ.unit
            ~branches:(module Nat.N1)
            ~max_proofs_verified:(module Nat.N1)
            ~name:"blockchain-snark"
            ~constraint_constants:
              (* Dummy values *)
              { sub_windows_per_window = 0
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
            ~choices:(fun ~self:_ ->
              [ { identifier = "main"
                ; prevs = [ side_loaded_tag ]
                ; feature_flags = Plonk_types.Features.none_bool
                ; main =
                    (fun { public_input = self } ->
                      let prev =
                        exists Field.typ ~request:(fun () -> Prev_input)
                      in
                      let proof =
                        exists (Typ.Internal.ref ()) ~request:(fun () -> Proof)
                      in
                      let vk =
                        exists (Typ.Internal.ref ()) ~request:(fun () ->
                            Verifier_index )
                      in
                      as_prover (fun () ->
                          let vk = As_prover.Ref.get vk in
                          Side_loaded.in_prover side_loaded_tag vk ) ;
                      let vk =
                        exists Side_loaded.Verification_key.typ
                          ~compute:(fun () -> As_prover.Ref.get vk)
                      in
                      Side_loaded.in_circuit side_loaded_tag vk ;
                      let is_base_case = Field.equal Field.zero self in
                      let self_correct = Field.(equal (one + prev) self) in
                      Boolean.Assert.any [ self_correct; is_base_case ] ;
                      { previous_proof_statements =
                          [ { public_input = prev
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

    let _example1 =
      let (), (), b1 =
        Common.time "b1" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler No_recursion.example_input
                       (Side_loaded.Proof.of_proof No_recursion.example_proof)
                       (Side_loaded.Verification_key.of_compiled
                          No_recursion.tag ) )
                  Field.Constant.one ) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
      (Field.Constant.one, b1)

    let _example2 =
      let (), (), b2 =
        Common.time "b2" (fun () ->
            Promise.block_on_async_exn (fun () ->
                step
                  ~handler:
                    (handler Fake_1_recursion.example_input
                       (Side_loaded.Proof.of_proof
                          Fake_1_recursion.example_proof )
                       (Side_loaded.Verification_key.of_compiled
                          Fake_1_recursion.tag ) )
                  Field.Constant.one ) )
      in
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.one, b2) ] ) ) ;
      (Field.Constant.one, b2)

    let () =
      Tests.add_slow ~name:"foo" ~f:(fun () ->
          let (), (), b3 =
            Common.time "b3" (fun () ->
                Promise.block_on_async_exn (fun () ->
                    step
                      ~handler:
                        (handler Fake_2_recursion.example_input
                           (Side_loaded.Proof.of_proof
                              Fake_2_recursion.example_proof )
                           (Side_loaded.Verification_key.of_compiled
                              Fake_2_recursion.tag ) )
                      Field.Constant.one ) )
          in
          Or_error.ok_exn
            (Promise.block_on_async_exn (fun () ->
                 Proof.verify_promise [ (Field.Constant.one, b3) ] ) ) )
  end
end

(* module Test_uncorrelated_bulletproof_challenges = struct
 *   let () = Backtrace.elide := false
 * 
 *   let () = Snarky_backendless.Snark0.set_eval_constraints true
 * 
 *   module Statement = struct
 *     type t = unit
 * 
 *     let to_field_elements () = [||]
 *   end
 * 
 *   module A = Statement
 *   module A_value = Statement
 * 
 *   let typ = Impls.Step.Typ.unit
 * 
 *   module Branches = Nat.N1
 *   module Max_proofs_verified = Nat.N2
 * 
 *   let tag =
 *     let tagname = "" in
 *     Tag.create ~kind:Compiled tagname
 * 
 *   let rule : _ Inductive_rule.t =
 *     let open Impls.Step in
 *     { identifier = "main"
 *     ; prevs = [ tag; tag ]
 *     ; main =
 *         (fun { public_input = () } ->
 *           let dummy_proof =
 *             As_prover.Ref.create (fun () ->
 *                 Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15 )
 *           in
 *           { previous_proof_statements =
 *               [ { public_input = ()
 *                 ; proof = dummy_proof
 *                 ; proof_must_verify = Boolean.false_
 *                 }
 *               ; { public_input = ()
 *                 ; proof = dummy_proof
 *                 ; proof_must_verify = Boolean.false_
 *                 }
 *               ]
 *           ; public_output = ()
 *           ; auxiliary_output = ()
 *           } )
 *     ; feature_flags = Plonk_types.Features.none_bool
 *     }
 * 
 *   (\* module M = struct
 *    *   module IR = Inductive_rule.T (A) (A_value) (A) (A_value) (A) (A_value)
 *    *   module HIR = H4.T (IR)
 *    * 
 *    *   let max_local_max_proofs_verifieds ~self (type n)
 *    *       (module Max_proofs_verified : Nat.Intf with type n = n) branches choices
 *    *       =
 *    *     let module Local_max_proofs_verifieds = struct
 *    *       type t = (int, Max_proofs_verified.n) Vector.t
 *    *     end in
 *    *     let module M =
 *    *       H4.Map (IR) (E04 (Local_max_proofs_verifieds))
 *    *         (struct
 *    *           module V = H4.To_vector (Int)
 *    *           module HT = H4.T (Tag)
 *    * 
 *    *           module M =
 *    *             H4.Map (Tag) (E04 (Int))
 *    *               (struct
 *    *                 let f (type a b c d) (t : (a, b, c, d) Tag.t) : int =
 *    *                   if Type_equal.Id.same t.id self then
 *    *                     Nat.to_int Max_proofs_verified.n
 *    *                   else
 *    *                     let (module M) = Types_map.max_proofs_verified t in
 *    *                     Nat.to_int M.n
 *    *               end)
 *    * 
 *    *           let f :
 *    *               type a b c d. (a, b, c, d) IR.t -> Local_max_proofs_verifieds.t
 *    *               =
 *    *            fun rule ->
 *    *             let (T (_, l)) = HT.length rule.prevs in
 *    *             Vector.extend_front_exn
 *    *               (V.f l (M.f rule.prevs))
 *    *               Max_proofs_verified.n 0
 *    *         end)
 *    *     in
 *    *     let module V = H4.To_vector (Local_max_proofs_verifieds) in
 *    *     let padded = V.f branches (M.f choices) |> Vector.transpose in
 *    *     (padded, Maxes.m padded)
 *    * 
 *    *   module Lazy_ (A : T0) = struct
 *    *     type t = A.t Lazy.t
 *    *   end
 *    * 
 *    *   module Lazy_keys = struct
 *    *     type t =
 *    *       (Impls.Step.Keypair.t * Dirty.t) Lazy.t
 *    *       * (Kimchi_bindings.Protocol.VerifierIndex.Fp.t * Dirty.t) Lazy.t
 *    * 
 *    *     (\\* TODO Think this is right.. *\\)
 *    *   end
 *    * 
 *    *   let compile :
 *    *       (   unit
 *    *        -> (Max_proofs_verified.n, Max_proofs_verified.n) Proof.t Promise.t )
 *    *       * _
 *    *       * _ =
 *    *     let self = tag in
 *    *     let snark_keys_header kind constraint_system_hash =
 *    *       { Snark_keys_header.header_version = Snark_keys_header.header_version
 *    *       ; kind
 *    *       ; constraint_constants
 *    *       ; commits =
 *    *           { mina = Mina_version.commit_id
 *    *           ; marlin = Mina_version.marlin_commit_id
 *    *           }
 *    *       ; length = (\\* This is a dummy, it gets filled in on read/write. *\\) 0
 *    *       ; commit_date = Mina_version.commit_date
 *    *       ; constraint_system_hash
 *    *       ; identifying_hash =
 *    *           (\\* TODO: Proper identifying hash. *\\)
 *    *           constraint_system_hash
 *    *       }
 *    *     in
 *    *     let T = Max_proofs_verified.eq in
 *    *     let prev_varss_n = Branches.n in
 *    *     let prev_varss_length : _ Length.t = S Z in
 *    *     let T = Nat.eq_exn prev_varss_n Branches.n in
 *    *     let padded, (module Maxes) =
 *    *       max_local_max_proofs_verifieds
 *    *         (module Max_proofs_verified)
 *    *         prev_varss_length [ rule ] ~self:self.id
 *    *     in
 *    *     let full_signature = { Full_signature.padded; maxes = (module Maxes) } in
 *    *     let feature_flags = Plonk_types.Features.none in
 *    *     let actual_feature_flags = Plonk_types.Features.none_bool in
 *    *     let wrap_domains =
 *    *       let module M =
 *    *         Wrap_domains.Make (A) (A_value) (A) (A_value) (A) (A_value)
 *    *       in
 *    *       M.f full_signature prev_varss_n prev_varss_length ~feature_flags
 *    *         ~max_proofs_verified:(module Max_proofs_verified)
 *    *     in
 *    *     let module Branch_data = struct
 *    *       type ('vars, 'vals, 'n, 'm) t =
 *    *         ( A.t
 *    *         , A_value.t
 *    *         , A.t
 *    *         , A_value.t
 *    *         , A.t
 *    *         , A_value.t
 *    *         , Max_proofs_verified.n
 *    *         , Branches.n
 *    *         , 'vars
 *    *         , 'vals
 *    *         , 'n
 *    *         , 'm )
 *    *         Step_branch_data.t
 *    *     end in
 *    *     let proofs_verifieds = Vector.[ 2 ] in
 *    *     let (T inner_step_data as step_data) =
 *    *       Step_branch_data.create ~index:0 ~feature_flags ~actual_feature_flags
 *    *         ~max_proofs_verified:Max_proofs_verified.n ~branches:Branches.n ~self
 *    *         ~public_input:(Input typ) ~auxiliary_typ:typ A.to_field_elements
 *    *         A_value.to_field_elements rule ~wrap_domains ~proofs_verifieds
 *    *     in
 *    *     let step_domains = Vector.[ inner_step_data.domains ] in
 *    *     let step_keypair =
 *    *       let etyp =
 *    *         Impls.Step.input ~feature_flags ~proofs_verified:Max_proofs_verified.n
 *    *           ~wrap_rounds:Tock.Rounds.n
 *    *       in
 *    *       let (T (typ, _conv, conv_inv)) = etyp in
 *    *       let main () () =
 *    *         let res = inner_step_data.main ~step_domains () in
 *    *         Impls.Step.with_label "conv_inv" (fun () -> conv_inv res)
 *    *       in
 *    *       let open Impls.Step in
 *    *       let k_p =
 *    *         lazy
 *    *           (let cs =
 *    *              constraint_system ~input_typ:Typ.unit ~return_typ:typ main
 *    *            in
 *    *            let cs_hash = Md5.to_hex (R1CS_constraint_system.digest cs) in
 *    *            ( Type_equal.Id.uid self.id
 *    *            , snark_keys_header
 *    *                { type_ = "step-proving-key"
 *    *                ; identifier = inner_step_data.rule.identifier
 *    *                }
 *    *                cs_hash
 *    *            , inner_step_data.index
 *    *            , cs ) )
 *    *       in
 *    *       let k_v =
 *    *         lazy
 *    *           (let id, _header, index, cs = Lazy.force k_p in
 *    *            let digest = R1CS_constraint_system.digest cs in
 *    *            ( id
 *    *            , snark_keys_header
 *    *                { type_ = "step-verification-key"
 *    *                ; identifier = inner_step_data.rule.identifier
 *    *                }
 *    *                (Md5.to_hex digest)
 *    *            , index
 *    *            , digest ) )
 *    *       in
 *    *       Cache.Step.read_or_generate
 *    *         ~prev_challenges:(Nat.to_int (fst inner_step_data.proofs_verified))
 *    *         [] k_p k_v
 *    *         (Snarky_backendless.Typ.unit ())
 *    *         typ main
 *    *     in
 *    *     let step_vks =
 *    *       let module V = H4.To_vector (Lazy_keys) in
 *    *       lazy
 *    *         (Vector.map [ step_keypair ] ~f:(fun (_, vk) ->
 *    *              Tick.Keypair.vk_commitments (fst (Lazy.force vk)) ) )
 *    *     in
 *    *     let wrap_main _ =
 *    *       let module SC' = SC in
 *    *       let open Impls.Wrap in
 *    *       let open Wrap_main_inputs in
 *    *       let open Wrap_main in
 *    *       let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
 *    *       let y = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0) in
 *    *       let z = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 0) in
 *    *       let g = Inner_curve.one in
 *    *       let sponge = Sponge.create sponge_params in
 *    *       Sponge.absorb sponge x ;
 *    *       ignore (Sponge.squeeze_field sponge : Field.t) ;
 *    *       ignore
 *    *         ( SC'.to_field_checked'
 *    *             (module Impl)
 *    *             ~num_bits:16
 *    *             (Kimchi_backend_common.Scalar_challenge.create x)
 *    *           : Field.t * Field.t * Field.t ) ;
 *    *       ignore (Ops.scale_fast g ~num_bits:5 (Shifted_value x) : Inner_curve.t) ;
 *    *       ignore
 *    *         ( Wrap_verifier.Scalar_challenge.endo g ~num_bits:4
 *    *             (Kimchi_backend_common.Scalar_challenge.create x)
 *    *           : Field.t * Field.t ) ;
 *    *       for i = 0 to 64000 do
 *    *         assert_r1cs x y z
 *    *       done
 *    *     in
 *    *     let (wrap_pk, wrap_vk), disk_key =
 *    *       let open Impls.Wrap in
 *    *       let (T (typ, conv, _conv_inv)) = input () in
 *    *       let main x () : unit = wrap_main (conv x) in
 *    *       let self_id = Type_equal.Id.uid self.id in
 *    *       let disk_key_prover =
 *    *         lazy
 *    *           (let cs =
 *    *              constraint_system ~input_typ:typ ~return_typ:Typ.unit main
 *    *            in
 *    *            let cs_hash = Md5.to_hex (R1CS_constraint_system.digest cs) in
 *    *            ( self_id
 *    *            , snark_keys_header
 *    *                { type_ = "wrap-proving-key"; identifier = "" }
 *    *                cs_hash
 *    *            , cs ) )
 *    *       in
 *    *       let disk_key_verifier =
 *    *         lazy
 *    *           (let id, _header, cs = Lazy.force disk_key_prover in
 *    *            let digest = R1CS_constraint_system.digest cs in
 *    *            ( id
 *    *            , snark_keys_header
 *    *                { type_ = "wrap-verification-key"; identifier = "" }
 *    *                (Md5.to_hex digest)
 *    *            , digest ) )
 *    *       in
 *    *       let r =
 *    *         Common.time "wrap read or generate " (fun () ->
 *    *             Cache.Wrap.read_or_generate ~prev_challenges:2 [] disk_key_prover
 *    *               disk_key_verifier typ Typ.unit main )
 *    *       in
 *    *       (r, disk_key_verifier)
 *    *     in
 *    *     let wrap_vk = Lazy.map wrap_vk ~f:fst in
 *    *     let module S = Step.Make (A) (A_value) (Max_proofs_verified) in
 *    *     let prover =
 *    *       let module Z = H4.Zip (Branch_data) (E04 (Impls.Step.Keypair)) in
 *    *       let f :
 *    *              ( unit * (unit * unit)
 *    *              , unit * (unit * unit)
 *    *              , Nat.N2.n * (Nat.N2.n * unit)
 *    *              , Nat.N1.n * (Nat.N1.n * unit) )
 *    *              Branch_data.t
 *    *           -> Lazy_keys.t
 *    *           -> unit
 *    *           -> (Max_proofs_verified.n, Max_proofs_verified.n) Proof.t Promise.t
 *    *           =
 *    *        fun (T b as branch_data) (step_pk, step_vk) () ->
 *    *         let ((module Req) : (Max_proofs_verified.n, Maxes.ns) Requests.Wrap.t)
 *    *             =
 *    *           Requests.Wrap.create ()
 *    *         in
 *    *         let (module Requests) = b.requests in
 *    *         let _, prev_vars_length = b.proofs_verified in
 *    *         let step =
 *    *           let wrap_vk = Lazy.force wrap_vk in
 *    *           S.f branch_data () ~feature_flags ~prevs_length:prev_vars_length
 *    *             ~self ~public_input:(Input typ) ~auxiliary_typ:Impls.Step.Typ.unit
 *    *             ~step_domains ~self_dlog_plonk_index:wrap_vk.commitments
 *    *             (Impls.Step.Keypair.pk (fst (Lazy.force step_pk)))
 *    *             wrap_vk.index
 *    *         in
 *    *         let pairing_vk = fst (Lazy.force step_vk) in
 *    *         let wrap =
 *    *           let wrap_vk = Lazy.force wrap_vk in
 *    *           let%bind.Promise proof, (), (), _ = step ~maxes:(module Maxes) in
 *    *           let proof =
 *    *             { proof with
 *    *               statement =
 *    *                 { proof.statement with
 *    *                   messages_for_next_wrap_proof =
 *    *                     Compile.pad_messages_for_next_wrap_proof
 *    *                       (module Maxes)
 *    *                       proof.statement.messages_for_next_wrap_proof
 *    *                 }
 *    *             }
 *    *           in
 *    *           let%map.Promise proof =
 *    *             let module Pairing_acc = Tock.Inner_curve.Affine in
 *    *             (\\* The prover for wrapping a proof *\\)
 *    *             let wrap (type actual_branching)
 *    *                 ~(max_proofs_verified : Max_proofs_verified.n Nat.t)
 *    *                 (module Max_local_max_proofs_verifieds : Hlist.Maxes.S
 *    *                   with type ns = Maxes.ns
 *    *                    and type length = Max_proofs_verified.n ) ~dlog_plonk_index
 *    *                 wrap_main to_field_elements ~pairing_vk ~step_domains
 *    *                 ~wrap_domains ~pairing_plonk_indices pk
 *    *                 ({ statement = prev_statement
 *    *                  ; prev_evals
 *    *                  ; proof
 *    *                  ; index = which_index
 *    *                  } :
 *    *                   ( _
 *    *                   , _
 *    *                   , (_, actual_branching) Vector.t
 *    *                   , (_, actual_branching) Vector.t
 *    *                   , Maxes.ns
 *    *                     H1.T(P.Base.Messages_for_next_proof_over_same_field.Wrap)
 *    *                     .t
 *    *                   , ( ( Tock.Field.t
 *    *                       , Tock.Field.t array )
 *    *                       Plonk_types.All_evals.t
 *    *                     , Max_proofs_verified.n )
 *    *                     Vector.t )
 *    *                   P.Base.Step.t ) =
 *    *               let prev_messages_for_next_wrap_proof =
 *    *                 let module M =
 *    *                   H1.Map
 *    *                     (P.Base.Messages_for_next_proof_over_same_field.Wrap)
 *    *                     (P.Base.Messages_for_next_proof_over_same_field.Wrap
 *    *                      .Prepared)
 *    *                     (struct
 *    *                       let f =
 *    *                         P.Base.Messages_for_next_proof_over_same_field.Wrap
 *    *                         .prepare
 *    *                     end)
 *    *                 in
 *    *                 M.f prev_statement.messages_for_next_wrap_proof
 *    *               in
 *    *               let prev_statement_with_hashes : _ Types.Step.Statement.t =
 *    *                 { proof_state =
 *    *                     { prev_statement.proof_state with
 *    *                       messages_for_next_step_proof =
 *    *                         (\\* TODO: Careful here... the length of
 *    *                            old_buletproof_challenges inside the messages_for_next_wrap_proof
 *    *                            might not be correct *\\)
 *    *                         Common.hash_messages_for_next_step_proof
 *    *                           ~app_state:to_field_elements
 *    *                           (P.Base.Messages_for_next_proof_over_same_field.Step
 *    *                            .prepare ~dlog_plonk_index
 *    *                              prev_statement.proof_state
 *    *                                .messages_for_next_step_proof )
 *    *                     }
 *    *                 ; messages_for_next_wrap_proof =
 *    *                     (let module M =
 *    *                        H1.Map
 *    *                          (P.Base.Messages_for_next_proof_over_same_field.Wrap
 *    *                           .Prepared)
 *    *                          (E01 (Digest.Constant))
 *    *                          (struct
 *    *                            let f (type n)
 *    *                                (m :
 *    *                                  n
 *    *                                  P.Base
 *    *                                  .Messages_for_next_proof_over_same_field
 *    *                                  .Wrap
 *    *                                  .Prepared
 *    *                                  .t ) =
 *    *                              let T =
 *    *                                Nat.eq_exn max_proofs_verified
 *    *                                  (Vector.length m.old_bulletproof_challenges)
 *    *                              in
 *    *                              Wrap_hack.hash_messages_for_next_wrap_proof
 *    *                                max_proofs_verified m
 *    *                          end)
 *    *                      in
 *    *                     let module V = H1.To_vector (Digest.Constant) in
 *    *                     V.f Max_local_max_proofs_verifieds.length
 *    *                       (M.f prev_messages_for_next_wrap_proof) )
 *    *                 }
 *    *               in
 *    *               let module O = Tick.Oracles in
 *    *               let public_input =
 *    *                 tick_public_input_of_statement ~max_proofs_verified
 *    *                   ~feature_flags:Plonk_types.Features.none
 *    *                   prev_statement_with_hashes
 *    *               in
 *    *               let prev_challenges =
 *    *                 Vector.map ~f:Ipa.Step.compute_challenges
 *    *                   prev_statement.proof_state.messages_for_next_step_proof
 *    *                     .old_bulletproof_challenges
 *    *               in
 *    *               let actual_proofs_verified = Vector.length prev_challenges in
 *    *               let lte =
 *    *                 Nat.lte_exn actual_proofs_verified
 *    *                   (Length.to_nat Max_local_max_proofs_verifieds.length)
 *    *               in
 *    *               let o =
 *    *                 let sgs =
 *    *                   let module M =
 *    *                     H1.Map
 *    *                       (P.Base.Messages_for_next_proof_over_same_field.Wrap
 *    *                        .Prepared)
 *    *                       (E01 (Tick.Curve.Affine))
 *    *                       (struct
 *    *                         let f :
 *    *                             type n.
 *    *                                n
 *    *                                P.Base.Messages_for_next_proof_over_same_field
 *    *                                .Wrap
 *    *                                .Prepared
 *    *                                .t
 *    *                             -> _ =
 *    *                          fun t -> t.challenge_polynomial_commitment
 *    *                       end)
 *    *                   in
 *    *                   let module V = H1.To_vector (Tick.Curve.Affine) in
 *    *                   V.f Max_local_max_proofs_verifieds.length
 *    *                     (M.f prev_messages_for_next_wrap_proof)
 *    *                 in
 *    *                 O.create pairing_vk
 *    *                   Vector.(
 *    *                     map2 (Vector.trim_front sgs lte) prev_challenges
 *    *                       ~f:(fun commitment cs ->
 *    *                         { Tick.Proof.Challenge_polynomial.commitment
 *    *                         ; challenges = Vector.to_array cs
 *    *                         } )
 *    *                     |> to_list)
 *    *                   public_input proof
 *    *               in
 *    *               let x_hat = O.(p_eval_1 o, p_eval_2 o) in
 *    *               let step_vk, _ = Lazy.force step_vk in
 *    *               let next_statement : _ Types.Wrap.Statement.In_circuit.t =
 *    *                 let scalar_chal f =
 *    *                   Scalar_challenge.map ~f:Challenge.Constant.of_tick_field
 *    *                     (f o)
 *    *                 in
 *    *                 let sponge_digest_before_evaluations =
 *    *                   O.digest_before_evaluations o
 *    *                 in
 *    *                 let plonk0 =
 *    *                   { Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.alpha =
 *    *                       scalar_chal O.alpha
 *    *                   ; beta = O.beta o
 *    *                   ; gamma = O.gamma o
 *    *                   ; zeta = scalar_chal O.zeta
 *    *                   ; joint_combiner =
 *    *                       Option.map (O.joint_combiner_chal o)
 *    *                         ~f:
 *    *                           (Scalar_challenge.map
 *    *                              ~f:Challenge.Constant.of_tick_field )
 *    *                   ; feature_flags = Plonk_types.Features.none_bool
 *    *                   }
 *    *                 in
 *    *                 let r = scalar_chal O.u in
 *    *                 let xi = scalar_chal O.v in
 *    *                 let to_field =
 *    *                   SC.to_field_constant
 *    *                     (module Tick.Field)
 *    *                     ~endo:Endo.Wrap_inner_curve.scalar
 *    *                 in
 *    *                 let module As_field = struct
 *    *                   let r = to_field r
 *    * 
 *    *                   let xi = to_field xi
 *    * 
 *    *                   let zeta = to_field plonk0.zeta
 *    * 
 *    *                   let alpha = to_field plonk0.alpha
 *    * 
 *    *                   let joint_combiner =
 *    *                     Option.map ~f:to_field plonk0.joint_combiner
 *    *                 end in
 *    *                 let domain =
 *    *                   Domain.Pow_2_roots_of_unity step_vk.domain.log_size_of_group
 *    *                 in
 *    *                 let w = step_vk.domain.group_gen in
 *    *                 (\\* Debug *\\)
 *    *                 [%test_eq: Tick.Field.t] w
 *    *                   (Tick.Field.domain_generator
 *    *                      ~log2_size:(Domain.log2_size domain) ) ;
 *    *                 let zetaw = Tick.Field.mul As_field.zeta w in
 *    *                 let tick_plonk_minimal =
 *    *                   { plonk0 with
 *    *                     zeta = As_field.zeta
 *    *                   ; alpha = As_field.alpha
 *    *                   ; joint_combiner = As_field.joint_combiner
 *    *                   }
 *    *                 in
 *    *                 let tick_combined_evals =
 *    *                   Plonk_checks.evals_of_split_evals
 *    *                     (module Tick.Field)
 *    *                     proof.openings.evals ~rounds:(Nat.to_int Tick.Rounds.n)
 *    *                     ~zeta:As_field.zeta ~zetaw
 *    *                 in
 *    *                 let tick_domain =
 *    *                   Plonk_checks.domain
 *    *                     (module Tick.Field)
 *    *                     domain ~shifts:Common.tick_shifts
 *    *                     ~domain_generator:Backend.Tick.Field.domain_generator
 *    *                 in
 *    *                 let tick_combined_evals =
 *    *                   Plonk_types.Evals.to_in_circuit tick_combined_evals
 *    *                 in
 *    *                 let tick_env =
 *    *                   let module Env_bool = struct
 *    *                     type t = bool
 *    * 
 *    *                     let true_ = true
 *    * 
 *    *                     let false_ = false
 *    * 
 *    *                     let ( &&& ) = ( && )
 *    * 
 *    *                     let ( ||| ) = ( || )
 *    * 
 *    *                     let any = List.exists ~f:Fn.id
 *    *                   end in
 *    *                   let module Env_field = struct
 *    *                     include Tick.Field
 *    * 
 *    *                     type bool = Env_bool.t
 *    * 
 *    *                     let if_ (b : bool) ~then_ ~else_ =
 *    *                       if b then then_ () else else_ ()
 *    *                   end in
 *    *                   Plonk_checks.scalars_env
 *    *                     (module Env_bool)
 *    *                     (module Env_field)
 *    *                     ~endo:Endo.Step_inner_curve.base
 *    *                     ~mds:Tick_field_sponge.params.mds
 *    *                     ~srs_length_log2:Common.Max_degree.step_log2
 *    *                     ~field_of_hex:(fun s ->
 *    *                       Kimchi_pasta.Pasta.Bigint256.of_hex_string s
 *    *                       |> Kimchi_pasta.Pasta.Fp.of_bigint )
 *    *                     ~domain:tick_domain tick_plonk_minimal tick_combined_evals
 *    *                 in
 *    *                 let combined_inner_product =
 *    *                   let open As_field in
 *    *                   Wrap.combined_inner_product (\\* Note: We do not pad here. *\\)
 *    *                     ~actual_proofs_verified:
 *    *                       (Nat.Add.create actual_proofs_verified)
 *    *                     { evals = proof.openings.evals; public_input = x_hat }
 *    *                     ~r ~xi ~zeta ~zetaw
 *    *                     ~old_bulletproof_challenges:prev_challenges ~env:tick_env
 *    *                     ~domain:tick_domain ~ft_eval1:proof.openings.ft_eval1
 *    *                     ~plonk:tick_plonk_minimal
 *    *                 in
 *    *                 let chal = Challenge.Constant.of_tick_field in
 *    *                 let sg_new, new_bulletproof_challenges, b =
 *    *                   let prechals =
 *    *                     Array.map (O.opening_prechallenges o) ~f:(fun x ->
 *    *                         let x =
 *    *                           Scalar_challenge.map
 *    *                             ~f:Challenge.Constant.of_tick_field x
 *    *                         in
 *    *                         x )
 *    *                   in
 *    *                   let chals =
 *    *                     Array.map prechals ~f:(fun x ->
 *    *                         Ipa.Step.compute_challenge x )
 *    *                   in
 *    *                   let challenge_polynomial =
 *    *                     unstage (Wrap.challenge_polynomial chals)
 *    *                   in
 *    *                   let open As_field in
 *    *                   let b =
 *    *                     let open Tick.Field in
 *    *                     challenge_polynomial zeta
 *    *                     + (r * challenge_polynomial zetaw)
 *    *                   in
 *    *                   let overwritten_prechals =
 *    *                     Array.map prechals
 *    *                       ~f:
 *    *                         (Scalar_challenge.map ~f:(fun _ ->
 *    *                              Challenge.Constant.of_tick_field
 *    *                                (Impls.Step.Field.Constant.of_int 100) ) )
 *    *                   in
 *    *                   let chals =
 *    *                     Array.map overwritten_prechals ~f:(fun x ->
 *    *                         Ipa.Step.compute_challenge x )
 *    *                   in
 *    *                   let sg_new =
 *    *                     let urs = Backend.Tick.Keypair.load_urs () in
 *    *                     Kimchi_bindings.Protocol.SRS.Fp.batch_accumulator_generate
 *    *                       urs 1 chals
 *    *                   in
 *    *                   let sg_new =
 *    *                     match sg_new with
 *    *                     | [| Kimchi_types.Finite x |] ->
 *    *                         x
 *    *                     | _ ->
 *    *                         assert false
 *    *                   in
 *    *                   let overwritten_prechals =
 *    *                     Array.map overwritten_prechals
 *    *                       ~f:Bulletproof_challenge.unpack
 *    *                   in
 *    * 
 *    *                   (sg_new, overwritten_prechals, b)
 *    *                 in
 *    *                 let plonk =
 *    *                   let module Field = struct
 *    *                     include Tick.Field
 *    * 
 *    *                     type nonrec bool = bool
 *    *                   end in
 *    *                   Wrap.Type1.derive_plonk
 *    *                     (module Field)
 *    *                     ~feature_flags:Plonk_types.Features.none
 *    *                     ~shift:Shifts.tick1 ~env:tick_env tick_plonk_minimal
 *    *                     tick_combined_evals
 *    *                 in
 *    *                 let shift_value =
 *    *                   Shifted_value.Type1.of_field
 *    *                     (module Tick.Field)
 *    *                     ~shift:Shifts.tick1
 *    *                 in
 *    *                 let branch_data : Composition_types.Branch_data.t =
 *    *                   { proofs_verified =
 *    *                       ( match actual_proofs_verified with
 *    *                       | Z ->
 *    *                           Composition_types.Branch_data.Proofs_verified.N0
 *    *                       | S Z ->
 *    *                           N1
 *    *                       | S (S Z) ->
 *    *                           N2
 *    *                       | _ ->
 *    *                           assert false )
 *    *                   ; domain_log2 =
 *    *                       Composition_types.Branch_data.Domain_log2.of_int_exn
 *    *                         step_vk.domain.log_size_of_group
 *    *                   }
 *    *                 in
 *    *                 let messages_for_next_wrap_proof :
 *    *                     _ P.Base.Messages_for_next_proof_over_same_field.Wrap.t =
 *    *                   { challenge_polynomial_commitment = sg_new
 *    *                   ; old_bulletproof_challenges =
 *    *                       Vector.map prev_statement.proof_state.unfinalized_proofs
 *    *                         ~f:(fun t ->
 *    *                           t.deferred_values.bulletproof_challenges )
 *    *                   }
 *    *                 in
 *    *                 { proof_state =
 *    *                     { deferred_values =
 *    *                         { xi
 *    *                         ; b = shift_value b
 *    *                         ; bulletproof_challenges =
 *    *                             Vector.of_array_and_length_exn
 *    *                               new_bulletproof_challenges Tick.Rounds.n
 *    *                         ; combined_inner_product =
 *    *                             shift_value combined_inner_product
 *    *                         ; branch_data
 *    *                         ; plonk =
 *    *                             { plonk with
 *    *                               zeta = plonk0.zeta
 *    *                             ; alpha = plonk0.alpha
 *    *                             ; beta = chal plonk0.beta
 *    *                             ; gamma = chal plonk0.gamma
 *    *                             ; lookup = Plonk_types.Opt.None
 *    *                             }
 *    *                         }
 *    *                     ; sponge_digest_before_evaluations =
 *    *                         Digest.Constant.of_tick_field
 *    *                           sponge_digest_before_evaluations
 *    *                     ; messages_for_next_wrap_proof
 *    *                     }
 *    *                 ; messages_for_next_step_proof =
 *    *                     prev_statement.proof_state.messages_for_next_step_proof
 *    *                 }
 *    *               in
 *    *               let messages_for_next_wrap_proof_prepared =
 *    *                 P.Base.Messages_for_next_proof_over_same_field.Wrap.prepare
 *    *                   next_statement.proof_state.messages_for_next_wrap_proof
 *    *               in
 *    *               let%map.Promise next_proof =
 *    *                 let (T (input, conv, _conv_inv)) = Impls.Wrap.input () in
 *    *                 Common.time "wrap proof" (fun () ->
 *    *                     Impls.Wrap.generate_witness_conv
 *    *                       ~f:(fun { Impls.Wrap.Proof_inputs.auxiliary_inputs
 *    *                               ; public_inputs
 *    *                               } () ->
 *    *                         Backend.Tock.Proof.create_async ~primary:public_inputs
 *    *                           ~auxiliary:auxiliary_inputs pk
 *    *                           ~message:
 *    *                             ( Vector.map2
 *    *                                 (Vector.extend_front_exn
 *    *                                    prev_statement.proof_state
 *    *                                      .messages_for_next_step_proof
 *    *                                      .challenge_polynomial_commitments
 *    *                                    max_proofs_verified
 *    *                                    (Lazy.force Dummy.Ipa.Wrap.sg) )
 *    *                                 messages_for_next_wrap_proof_prepared
 *    *                                   .old_bulletproof_challenges
 *    *                                 ~f:(fun sg chals ->
 *    *                                   { Tock.Proof.Challenge_polynomial.commitment =
 *    *                                       sg
 *    *                                   ; challenges = Vector.to_array chals
 *    *                                   } )
 *    *                             |> Wrap_hack.pad_accumulator ) )
 *    *                       ~input_typ:input
 *    *                       ~return_typ:(Snarky_backendless.Typ.unit ())
 *    *                       (fun x () : unit -> wrap_main (conv x))
 *    *                       { messages_for_next_step_proof =
 *    *                           prev_statement_with_hashes.proof_state
 *    *                             .messages_for_next_step_proof
 *    *                       ; proof_state =
 *    *                           { next_statement.proof_state with
 *    *                             messages_for_next_wrap_proof =
 *    *                               Wrap_hack.hash_messages_for_next_wrap_proof
 *    *                                 max_proofs_verified
 *    *                                 messages_for_next_wrap_proof_prepared
 *    *                           ; deferred_values =
 *    *                               { next_statement.proof_state.deferred_values with
 *    *                                 plonk =
 *    *                                   { next_statement.proof_state.deferred_values
 *    *                                       .plonk
 *    *                                     with
 *    *                                     lookup = None
 *    *                                   ; optional_column_scalars =
 *    *                                       { range_check0 = None
 *    *                                       ; range_check1 = None
 *    *                                       ; foreign_field_add = None
 *    *                                       ; foreign_field_mul = None
 *    *                                       ; xor = None
 *    *                                       ; rot = None
 *    *                                       ; lookup_gate = None
 *    *                                       ; runtime_tables = None
 *    *                                       }
 *    *                                   }
 *    *                               }
 *    *                           }
 *    *                       } )
 *    *               in
 *    *               ( { proof = next_proof
 *    *                 ; statement =
 *    *                     Types.Wrap.Statement.to_minimal
 *    *                       ~to_option:Plonk_types.Opt.to_option next_statement
 *    *                 ; prev_evals =
 *    *                     { Plonk_types.All_evals.evals =
 *    *                         { public_input = x_hat; evals = proof.openings.evals }
 *    *                     ; ft_eval1 = proof.openings.ft_eval1
 *    *                     }
 *    *                 }
 *    *                 : _ P.Base.Wrap.t )
 *    *             in
 *    *             wrap ~max_proofs_verified:Max_proofs_verified.n
 *    *               full_signature.maxes ~dlog_plonk_index:wrap_vk.commitments
 *    *               wrap_main A_value.to_field_elements ~pairing_vk
 *    *               ~step_domains:b.domains
 *    *               ~pairing_plonk_indices:(Lazy.force step_vks) ~wrap_domains
 *    *               (Impls.Wrap.Keypair.pk (fst (Lazy.force wrap_pk)))
 *    *               proof
 *    *           in
 *    *           Proof.T
 *    *             { proof with
 *    *               statement =
 *    *                 { proof.statement with
 *    *                   messages_for_next_step_proof =
 *    *                     { proof.statement.messages_for_next_step_proof with
 *    *                       app_state = ()
 *    *                     }
 *    *                 }
 *    *             }
 *    *         in
 *    *         wrap
 *    *       in
 *    *       f step_data step_keypair
 *    *     in
 *    *     let data : _ Types_map.Compiled.t =
 *    *       { branches = Branches.n
 *    *       ; feature_flags
 *    *       ; proofs_verifieds
 *    *       ; max_proofs_verified = (module Max_proofs_verified)
 *    *       ; public_input = typ
 *    *       ; wrap_key = Lazy.map wrap_vk ~f:Verification_key.commitments
 *    *       ; wrap_vk = Lazy.map wrap_vk ~f:Verification_key.index
 *    *       ; wrap_domains
 *    *       ; step_domains
 *    *       }
 *    *     in
 *    *     Types_map.add_exn self data ;
 *    *     (prover, wrap_vk, disk_key)
 *    * end
 *    * 
 *    * let step, wrap_vk, wrap_disk_key = M.compile
 *    * 
 *    * module Proof = struct
 *    *   type statement = A_value.t
 *    * 
 *    *   module Max_local_max_proofs_verified = Max_proofs_verified
 *    *   module Max_proofs_verified_vec = Nvector (Max_proofs_verified)
 *    *   include Proof.Make (Max_proofs_verified) (Max_local_max_proofs_verified)
 *    * 
 *    *   let id = wrap_disk_key
 *    * 
 *    *   let verification_key = wrap_vk
 *    * 
 *    *   let verify ts =
 *    *     verify_promise
 *    *       (module Max_proofs_verified)
 *    *       (module A_value)
 *    *       (Lazy.force verification_key)
 *    *       ts
 *    * 
 *    *   let statement (T p : t) = p.statement.messages_for_next_step_proof.app_state
 *    * end
 *    * 
 *    * let proof_with_stmt =
 *    *   let p = Promise.block_on_async_exn (fun () -> step ()) in
 *    *   ((), p)
 *    * 
 *    * let () =
 *    *   Tests.add_slow ~name:"should not be able to verify invalid proof"
 *    *     ~f:(fun () ->
 *    *       assert (
 *    *         Or_error.is_error
 *    *         @@ Promise.block_on_async_exn (fun () ->
 *    *                Proof.verify [ proof_with_stmt ] ) ) )
 *    * 
 *    * module Recurse_on_bad_proof = struct
 *    *   open Impls.Step
 *    * 
 *    *   let dummy_proof = Proof0.dummy Nat.N2.n Nat.N2.n Nat.N2.n ~domain_log2:15
 *    * 
 *    *   type _ Snarky_backendless.Request.t +=
 *    *     | Proof : (Nat.N2.n, Nat.N2.n) Proof0.t Snarky_backendless.Request.t
 *    * 
 *    *   let handler (proof : _ Proof0.t)
 *    *       (Snarky_backendless.Request.With { request; respond }) =
 *    *     match request with
 *    *     | Proof ->
 *    *         respond (Provide proof)
 *    *     | _ ->
 *    *         respond Unhandled
 *    * 
 *    *   let tag, _, p, Provers.[ step ] =
 *    *     Common.time "compile" (fun () ->
 *    *         compile_promise () ~public_input:(Input Typ.unit)
 *    *           ~auxiliary_typ:Typ.unit
 *    *           ~branches:(module Nat.N1)
 *    *           ~max_proofs_verified:(module Nat.N2)
 *    *           ~name:"recurse-on-bad" ~constraint_constants
 *    *           ~choices:(fun ~self:_ ->
 *    *             [ { identifier = "main"
 *    *               ; feature_flags = Plonk_types.Features.none_bool
 *    *               ; prevs = [ tag; tag ]
 *    *               ; main =
 *    *                   (fun { public_input = () } ->
 *    *                     let proof =
 *    *                       exists (Typ.Internal.ref ()) ~request:(fun () -> Proof)
 *    *                     in
 *    *                     { previous_proof_statements =
 *    *                         [ { public_input = ()
 *    *                           ; proof
 *    *                           ; proof_must_verify = Boolean.true_
 *    *                           }
 *    *                         ; { public_input = ()
 *    *                           ; proof
 *    *                           ; proof_must_verify = Boolean.true_
 *    *                           }
 *    *                         ]
 *    *                     ; public_output = ()
 *    *                     ; auxiliary_output = ()
 *    *                     } )
 *    *               }
 *    *             ] ) )
 *    * 
 *    *   module Proof = (val p)
 *    * end *\)
 * 
 *   (\* let () =
 *    *   Tests.add_slow
 *    *     ~name:
 *    *       "should not be able to create a recursive proof from an invalid proof"
 *    *     ~f:(fun () ->
 *    *       assert (
 *    *         try
 *    *           let (), (), proof =
 *    *             Promise.block_on_async_exn (fun () ->
 *    *                 Recurse_on_bad_proof.step
 *    *                   ~handler:
 *    *                     (Recurse_on_bad_proof.handler (snd proof_with_stmt))
 *    *                   () )
 *    *           in
 *    *           Or_error.is_error
 *    *           @@ Promise.block_on_async_exn (fun () ->
 *    *                  Recurse_on_bad_proof.Proof.verify_promise [ ((), proof) ] )
 *    *         with _ -> true ) ) *\)
 * end *)

let tests = [ ("Pickles", !Tests.l) ]
