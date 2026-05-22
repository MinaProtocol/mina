(** Standalone kimchi prover for the chunks2 leaf application body —
 *  isolates the app circuit from Pickles' step/wrap scaffolding so the
 *  witness dump under `KIMCHI_WITNESS_DUMP` reflects ONLY the app
 *  body's variable assignments.
 *
 *  Mirrors `app_circuit_chunks2` in `dump_circuit_impl.ml`: 2^17 + 1
 *  `Field.mul (fresh_zero) (fresh_zero)` fillers plus one Raw Generic
 *  row with seven copies of a fresh-zero. With the default Tick SRS
 *  size (max_poly_size = 2^15) and a 2^16-row domain, this triggers
 *  `num_chunks = 2` inside kimchi's PCS.
 *
 *  Required env vars:
 *  - `KIMCHI_WITNESS_DUMP=<path-template>` (the `%c` placeholder gets
 *    replaced with a monotonic counter; only one proof here, so
 *    counter is 0).
 *)

module Tick = Kimchi_backend.Pasta.Vesta_based_plonk
module Impl = Kimchi_pasta_snarky_backend.Step_impl

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let app_circuit () () =
  let open Impl in
  let fresh_zero () =
    exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
  in
  for _ = 0 to 1 lsl 17 do
    ignore (Field.mul (fresh_zero ()) (fresh_zero ()) : Field.t)
  done ;
  let fresh_zero = fresh_zero () in
  assert_
    (Raw
       { kind = Generic
       ; values =
           [| fresh_zero
            ; fresh_zero
            ; fresh_zero
            ; fresh_zero
            ; fresh_zero
            ; fresh_zero
            ; fresh_zero
           |]
       ; coeffs = [||]
       } )

let () =
  let constraint_system =
    Impl.constraint_system ~input_typ:Impl.Typ.unit
      ~return_typ:Impl.Typ.unit app_circuit
  in
  let proof_keypair =
    Tick.Keypair.create ~prev_challenges:0 constraint_system
  in
  let prover_index = Tick.Keypair.pk proof_keypair in
  let _proof, () =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } () ->
        let proof =
          Promise.block_on_async_exn (fun () ->
              Tick.Proof.create_async ~primary:public_inputs
                ~auxiliary:auxiliary_inputs ~message:[] prover_index )
        in
        (proof, ()) )
      ~input_typ:Impl.Typ.unit ~return_typ:Impl.Typ.unit app_circuit ()
  in
  ()
