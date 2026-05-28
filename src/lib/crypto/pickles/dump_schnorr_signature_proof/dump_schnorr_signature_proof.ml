(** Standalone kimchi prover for Mina's production Schnorr verifier.
 *
 *  Wraps `Signature_lib.Schnorr.Chunked.Checked.verifies` (via
 *  `Dump_schnorr_circuit_lib.schnorr_verify_circuit`) and signs
 *  with `Signature_lib.Schnorr.Chunked.sign ~signature_kind:Mainnet` —
 *  deterministic-nonce, no rejection-sampling fallback, matches the PS
 *  `Data.Schnorr.sign` post-iter-2c.
 *
 *  Shares the exact CS (and the `schnorr_verify_step_circuit`
 *  fixture) with `dump_schnorr_verify_circuit/` via
 *  `Dump_schnorr_circuit_lib`.
 *
 *  Output (in `<output_dir>`):
 *    - `vk.serde.json`        — kimchi `VerifierIndex<Vesta>` serde
 *    - `proof.serde.json`     — kimchi `ProverProof<Vesta>` serde
 *    - `public_input.json`    — 260-element LE-hex array of Tick.Field
 *                               values, the flattened (input || output)
 *                               public-input layout of the production
 *                               verifier circuit:
 *                                 [pk.x, pk.y,                    -- 2
 *                                  r,                             -- 1
 *                                  s_bits[0..254],                -- 255
 *                                  msg,                           -- 1
 *                                  output_bool]                   -- 1
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_signature_proof/
 *              dump_schnorr_signature_proof.exe -- <output_dir>
 *)

open Core_kernel
module Tick = Pickles.Backend.Tick
module Impl = Kimchi_pasta_snarky_backend.Step_impl
module Inner_curve = Pickles.Backend.Tick.Inner_curve
module Pallas_scalar = Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field
module Tick_field = Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field

(* Hex-emit a Tick.Field in LE-byte order (no `~reverse:true`) so PS's
   `fromHexLe` decodes it to the same value. Mirrors the convention used
   by the kimchi-stubs / snarky-kimchi binding layer. *)
let field_to_hex_le (x : Tick_field.t) : string =
  let bytes = Tick_field.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes in
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf
      (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let public_inputs_to_array (v : Tick_field.Vector.t) : Tick_field.t array =
  let n = Tick_field.Vector.length v in
  Array.init n ~f:(fun i -> Tick_field.Vector.get v i)

let write_public_input_json path (fields : Tick_field.t array) =
  let entries =
    Array.to_list fields |> List.map ~f:(fun f -> `String (field_to_hex_le f))
  in
  let json = `List entries in
  Out_channel.write_all path ~data:(Yojson.Safe.to_string json ^ "\n")

let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/schnorr/test/fixtures/schnorr_signature_proof"
  in
  Printf.printf "dump_schnorr_signature_proof: output_dir = %s\n" output_dir ;

  (* 1. Derive sk + message from FIXED constants (not `random ()`) so the
     emitted fixtures (vk/proof/public_input) and the resulting kimchi
     witness are reproducible run-to-run. This is what makes the
     OCaml<->PS witness byte-equality diff (`tools/witness_diff.sh
     schnorr`) deterministic: both sides prove the same (pk, r, s, msg).
     The signer itself is the production deterministic-nonce
     `Schnorr.Chunked.sign`. *)
  let sk = Pallas_scalar.of_int 42 in
  let pk_point = Inner_curve.scale Inner_curve.one sk in
  let pk_x, pk_y = Inner_curve.to_affine_exn pk_point in
  let msg_field = Tick_field.of_int 7 in
  let message_chunked =
    Random_oracle.Input.Chunked.field_elements [| msg_field |]
  in
  let r, s =
    Signature_lib.Schnorr.Chunked.sign
      ~signature_kind:Mina_signature_kind.Mainnet sk message_chunked
  in
  Printf.printf "schnorr: signed; pk.x (hex LE) = %s\n" (field_to_hex_le pk_x) ;
  Printf.printf "  r (hex LE) = %s\n" (field_to_hex_le r) ;
  (* Sanity: production unchecked verifier accepts. *)
  let ok_unchecked =
    Signature_lib.Schnorr.Chunked.verify
      ~signature_kind:Mina_signature_kind.Mainnet (r, s) pk_point
      message_chunked
  in
  assert ok_unchecked ;

  (* 2. Compile + keypair for the flat-typ wrapper around the
     production verifier. Using the production typ tuple3 directly
     (with `Inner_curve.typ` etc.) trips a snarky-backendless asymmetry
     where `Impl.constraint_system` runs the input typ's `check` but
     `generate_witness_conv` does NOT — leading to a CS-vs-witness var
     count mismatch and an OOB in `compute_witness`. The flat-typ
     wrapper re-runs the same `assert_on_curve` + 255 boolean checks
     inside the body, so both compile and witness see them. *)
  let constraint_system =
    Impl.constraint_system ~input_typ:Dump_schnorr_circuit_lib.input_typ
      ~return_typ:Dump_schnorr_circuit_lib.return_typ
      Dump_schnorr_circuit_lib.schnorr_verify_circuit
  in
  let proof_keypair =
    Tick.Keypair.create ~prev_challenges:0 constraint_system
  in
  let prover_index = Tick.Keypair.pk proof_keypair in
  let verifier_index = Tick.Keypair.vk proof_keypair in

  (* 3. Build the flat 259-field input array in the same order the
     circuit expects: [pk.x; pk.y; r; s_bit_0..s_bit_254; msg]. Take
     the first 255 bits of [Pallas_scalar.to_bits s] (255 = scalar
     size_in_bits). *)
  let s_bits =
    let bits = Pallas_scalar.to_bits s in
    Core_kernel.List.take bits 255
  in
  let s_bit_fields =
    Core_kernel.List.map s_bits ~f:(fun b ->
        if b then Tick_field.one else Tick_field.zero )
  in
  let inputs : Tick_field.t array =
    Array.of_list ([ pk_x; pk_y; r ] @ s_bit_fields @ [ msg_field ])
  in
  let proof_high_level, bool_output, public_inputs =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } b_out ->
        let proof =
          Promise.block_on_async_exn (fun () ->
              Tick.Proof.create_async ~message:[] ~primary:public_inputs
                ~auxiliary:auxiliary_inputs prover_index )
        in
        (proof, b_out, public_inputs) )
      ~input_typ:Dump_schnorr_circuit_lib.input_typ
      ~return_typ:Dump_schnorr_circuit_lib.return_typ
      Dump_schnorr_circuit_lib.schnorr_verify_circuit inputs
  in
  Printf.printf "schnorr: generated kimchi proof (output=%b); serializing...\n"
    bool_output ;

  (* 4. `to_backend_with_public_evals'` converts the OCaml-side
     `with_public_evals` (which wraps `Plonk_types.Proof.t`) to the
     kimchi-protocol-level `Kimchi_types.proof_with_public` that
     `Kimchi_bindings.Protocol.Proof.Fp.to_serde_json` expects.
     `primary_input` is passed empty: serde skips the `public` field,
     and PS reinjects it via `set_public_` before verifying. *)
  let backend_proof =
    Tick.Proof.to_backend_with_public_evals' [] [||] proof_high_level
  in

  let vk_json =
    Kimchi_bindings.Protocol.VerifierIndex.Fp.to_serde_json verifier_index
  in
  Out_channel.write_all (output_dir ^ "/vk.serde.json") ~data:vk_json ;

  let proof_json =
    Kimchi_bindings.Protocol.Proof.Fp.to_serde_json backend_proof
  in
  Out_channel.write_all (output_dir ^ "/proof.serde.json") ~data:proof_json ;

  (* `public_inputs` from `generate_witness_conv` already contains all
     260 fields in the typ-flattening order (pk_x, pk_y, r, s_bits[0..254],
     msg, output_bool) — exactly what the PS verifier injects. *)
  let pi_array = public_inputs_to_array public_inputs in
  write_public_input_json (output_dir ^ "/public_input.json") pi_array ;

  Printf.printf
    "schnorr: wrote vk.serde.json + proof.serde.json + public_input.json (%d \
     fields)\n"
    (Array.length pi_array)
