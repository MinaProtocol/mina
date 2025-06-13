(** Testing
   -------

   Component: Pickles
   Subject: Test sideloaded with feature flags
   Invocation: \
    dune exec src/lib/pickles/test/test_side_loaded_with_feature_flags.exe
*)

open Pickles_types
module SC = Pickles.Scalar_challenge

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Core_kernel.Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

module Statement = struct
  (* type t = Field.t *)

  (* let to_field_elements x = [| x |] *)

  module Constant = struct
    type t = Field.Constant.t [@@deriving bin_io]

    (* let to_field_elements x = [| x |] *)
  end
end

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
          ~max_proofs_verified:(module Nat.N0)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Plonk_types.Features.none_bool
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
    (Field.Constant.zero, b0)

  (* used later *)
  let example_input, example_proof = example

  let test_verify () =
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ example ]))
end

module Fake_1_recursion = struct
  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N1)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Plonk_types.Features.none_bool
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
    (Field.Constant.zero, b0)

  let test_verify () =
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ example ]))

  let example_input, example_proof = example
end

module Fake_2_recursion = struct
  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~override_wrap_domain:Pickles_base.Proofs_verified.N1
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N2)
          ~name:"blockchain-snark"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Plonk_types.Features.none_bool
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
    (Field.Constant.zero, b0)

  (* used later *)
  let example_input, example_proof = example

  let test_verify () =
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ example ]))
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
    Plonk_types.Features.(map none ~f:(fun _ -> Opt.Flag.Maybe))

  let side_loaded_tag =
    Side_loaded.create ~name:"foo"
      ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
      ~feature_flags:maybe_features ~typ:Field.typ

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N1)
          ~name:"blockchain-snark"
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
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                    in
                    let vk =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Verifier_index )
                    in
                    as_prover (fun () ->
                        let vk = As_prover.read (Typ.prover_value ()) vk in
                        Side_loaded.in_prover side_loaded_tag vk ) ;
                    let vk =
                      exists Pickles.Side_loaded.Verification_key.typ
                        ~compute:(fun () ->
                          As_prover.read (Typ.prover_value ()) vk )
                    in
                    Side_loaded.in_circuit side_loaded_tag vk ;
                    let is_base_case = Field.equal Field.zero self in
                    let self_correct = Field.(equal (one + prev) self) in
                    Boolean.Assert.any [ self_correct; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
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

  let test_verify_example1 () =
    let (), (), b1 =
      Common.time "b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              let%bind.Promise vk =
                Side_loaded.Verification_key.of_compiled_promise
                  No_recursion.tag
              in
              step
                ~handler:
                  (handler No_recursion.example_input
                     (Side_loaded.Proof.of_proof No_recursion.example_proof)
                     vk )
                Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b1) ] ) )

  let test_verify_example2 () =
    let (), (), b2 =
      Common.time "b2" (fun () ->
          Promise.block_on_async_exn (fun () ->
              let%bind.Promise vk =
                Side_loaded.Verification_key.of_compiled_promise
                  Fake_1_recursion.tag
              in
              step
                ~handler:
                  (handler Fake_1_recursion.example_input
                     (Side_loaded.Proof.of_proof Fake_1_recursion.example_proof)
                     vk )
                Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b2) ] ) )

  let test_verify_example3 () =
    let (), (), b3 =
      Common.time "b3" (fun () ->
          Promise.block_on_async_exn (fun () ->
              let%bind.Promise vk =
                Side_loaded.Verification_key.of_compiled_promise
                  Fake_2_recursion.tag
              in
              step
                ~handler:
                  (handler Fake_2_recursion.example_input
                     (Side_loaded.Proof.of_proof Fake_2_recursion.example_proof)
                     vk )
                Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b3) ] ) )
end

let () =
  let open Alcotest in
  run "Step side-loaded with feature flags"
    [ ("No recursion", [ test_case "verify" `Quick No_recursion.test_verify ])
    ; ( "Fake 1 recursion"
      , [ test_case "verify" `Quick Fake_1_recursion.test_verify ] )
    ; ( "Fake 2 recursion"
      , [ test_case "verify" `Quick Fake_2_recursion.test_verify ] )
    ; ( "Simple chain"
      , [ test_case "verify 1" `Quick Simple_chain.test_verify_example1
        ; test_case "verify 2" `Quick Simple_chain.test_verify_example2
        ; test_case "verify 3" `Quick Simple_chain.test_verify_example3
        ] )
    ]
