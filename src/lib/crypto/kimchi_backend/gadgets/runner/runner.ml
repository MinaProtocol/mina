(* Step circuit Impl *)
module Tick = Kimchi_backend.Pasta.Vesta_based_plonk
module Impl = Snarky_backendless.Snark.Run.Make (Tick)

let generate_and_verify_proof ?cs circuit =
  (* Generate constraint system for the circuit *)
  let constraint_system =
    match cs with
    | Some cs ->
        cs
    | None ->
        Impl.constraint_system ~input_typ:Impl.Typ.unit
          ~return_typ:Impl.Typ.unit (fun () () -> circuit ())
  in
  (* Generate the indexes from the constraint system *)
  let proof_keypair =
    Tick.Keypair.create ~prev_challenges:0 constraint_system
  in
  let prover_index = Tick.Keypair.pk proof_keypair in
  let proof, (() as _public_output) =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs }
              next_statement_hashed ->
        let proof =
          (* Only block_on_async for testing; do not do this in production!! *)
          Promise.block_on_async_exn (fun () ->
              (* TODO(dw) pass runtime tables *)
              Tick.Proof.create_and_verify_async ~primary:public_inputs
                ~auxiliary:auxiliary_inputs ~runtime_tables:[||] ~message:[]
                prover_index )
        in
        (proof, next_statement_hashed) )
      ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit
      (fun () () -> circuit ())
      ()
  in

  (* TODO: Once verifier index changes are merged
   *   - Switch above create_and_verify_async to create_async
   *   - Remove create_and_verify_async
   *   - Enable checks below *)

  (*
    (* Verify proof *)
    let verifier_index = Tick.Keypair.vk proof_keypair in
    (* We have an empty public input; create an empty vector. *)
    let public_input = Kimchi_bindings.FieldVectors.Fp.create () in
    (* Assert that the proof verifies. *)
    assert (Tick.Proof.verify ~message:[] proof verifier_index public_input) ;
  *)
  (constraint_system, proof_keypair, proof)
