module SC = Pickles.Scalar_challenge
open Pickles.Impls.Step

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let dummy_constraints () =
  Impl.(
    let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
    let g =
      exists Pickles.Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
          Pickles.Backend.Tick.Inner_curve.(to_affine_exn one) )
    in
    ignore
      ( SC.to_field_checked'
          (module Impl)
          ~num_bits:16
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t * Field.t ) ;
    ignore
      ( Pickles.Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Pickles.Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Pickles.Step_verifier.Scalar_challenge.endo g ~num_bits:4
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t ))

let tag, _, p, Pickles.Provers.[ step ] =
  Pickles.compile_promise () ~public_input:(Input Field.typ)
    ~auxiliary_typ:Typ.unit
    ~max_proofs_verified:(module Pickles_types.Nat.N0)
    ~name:"wrap-proof-demo"
    ~choices:(fun ~self:_ ->
      [ { identifier = "main"
        ; prevs = []
        ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
        ; main =
            (fun { public_input = self } ->
              dummy_constraints () ;
              Field.Assert.equal self Field.zero ;
              Promise.return
                { Pickles.Inductive_rule.previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
        }
      ] )

let _ = tag

module Proof = (val p)

let test_extra_lr_entry_rejected () =
  let (), (), proof =
    Promise.block_on_async_exn (fun () -> step Field.Constant.zero)
  in
  (* The untampered proof verifies. *)
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Field.Constant.zero, proof) ] ) ) ;
  let tampered = Pickles.Proof.For_tests.append_lr_entry proof in
  match
    Promise.block_on_async_exn (fun () ->
        Proof.verify_promise [ (Field.Constant.zero, tampered) ] )
  with
  | Ok () ->
      Alcotest.fail "a proof with an extra lr entry was accepted"
  | Error _ ->
      ()
  | exception e ->
      Alcotest.failf "verification raised instead of rejecting: %s"
        (Exn.to_string e)

let () =
  Alcotest.run "Wrap proof"
    [ ( "lr length"
      , [ Alcotest.test_case "extra lr entry is rejected" `Slow
            test_extra_lr_entry_rejected
        ] )
    ]
