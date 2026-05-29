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

(* Compile + keypair for the flat-typ wrapper around the production
   verifier. The VK is input-independent (a function of the circuit
   only), so we compile ONCE and reuse it for every (sk, msg) case.
   Using the production typ tuple3 directly (with `Inner_curve.typ` etc.)
   trips a snarky-backendless asymmetry where `Impl.constraint_system`
   runs the input typ's `check` but `generate_witness_conv` does NOT —
   leading to a CS-vs-witness var count mismatch and an OOB in
   `compute_witness`. The flat-typ wrapper re-runs the same
   `assert_on_curve` + 255 boolean checks inside the body, so both
   compile and witness see them. *)
let constraint_system =
  Impl.constraint_system ~input_typ:Dump_schnorr_circuit_lib.input_typ
    ~return_typ:Dump_schnorr_circuit_lib.return_typ
    Dump_schnorr_circuit_lib.schnorr_verify_circuit

let proof_keypair = Tick.Keypair.create ~prev_challenges:0 constraint_system

let prover_index = Tick.Keypair.pk proof_keypair

let verifier_index = Tick.Keypair.vk proof_keypair

let vk_json =
  Kimchi_bindings.Protocol.VerifierIndex.Fp.to_serde_json verifier_index

(* Sign (sk, msg) with the production deterministic-nonce signer, prove
   the verifier circuit on it, and write vk/proof/public_input to
   [output_dir]. Inputs are FIXED constants (not `random ()`) so the VK,
   public input, and the kimchi WITNESS are reproducible run-to-run —
   what makes the OCaml<->PS witness diff (`tools/witness_diff.sh
   schnorr`) deterministic. The PROOF itself is not: its
   commitment blinders are unseeded, so each run emits a different (but
   valid) proof. That's fine — the PS verify test accepts any valid
   proof for the (vk, public_input) pair. *)
let dump_case ~sk ~msg_field ~output_dir =
  let pk_point = Inner_curve.scale Inner_curve.one sk in
  let pk_x, pk_y = Inner_curve.to_affine_exn pk_point in
  let message_chunked =
    Random_oracle.Input.Chunked.field_elements [| msg_field |]
  in
  let r, s =
    Signature_lib.Schnorr.Chunked.sign
      ~signature_kind:Mina_signature_kind.Mainnet sk message_chunked
  in
  (* Sanity: production unchecked verifier accepts. *)
  assert (
    Signature_lib.Schnorr.Chunked.verify
      ~signature_kind:Mina_signature_kind.Mainnet (r, s) pk_point
      message_chunked ) ;
  (* Flat 259-field input: [pk.x; pk.y; r; s_bit_0..s_bit_254; msg].
     Take the first 255 bits of [Pallas_scalar.to_bits s]. *)
  let s_bit_fields =
    Pallas_scalar.to_bits s
    |> fun bits ->
    Core_kernel.List.take bits 255
    |> Core_kernel.List.map ~f:(fun b ->
           if b then Tick_field.one else Tick_field.zero )
  in
  let inputs : Tick_field.t array =
    Array.of_list ([ pk_x; pk_y; r ] @ s_bit_fields @ [ msg_field ])
  in
  let proof_high_level, _bool_output, public_inputs =
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
  (* `to_backend_with_public_evals'` converts the OCaml-side
     `with_public_evals` to the kimchi-protocol-level proof that
     `Proof.Fp.to_serde_json` expects. `primary_input` is passed empty:
     serde skips the `public` field, and PS reinjects it via
     `set_public_` before verifying. *)
  let backend_proof =
    Tick.Proof.to_backend_with_public_evals' [] [||] proof_high_level
  in
  Out_channel.write_all (output_dir ^ "/vk.serde.json") ~data:vk_json ;
  Out_channel.write_all
    (output_dir ^ "/proof.serde.json")
    ~data:(Kimchi_bindings.Protocol.Proof.Fp.to_serde_json backend_proof) ;
  (* `public_inputs` already contains all 260 fields in typ-flattening
     order (pk_x, pk_y, r, s_bits[0..254], msg, output_bool). *)
  let pi_array = public_inputs_to_array public_inputs in
  write_public_input_json (output_dir ^ "/public_input.json") pi_array ;
  Printf.printf "schnorr: wrote %s (pk.x=%s, %d fields)\n" output_dir
    (field_to_hex_le pk_x) (Array.length pi_array)

let () =
  let base_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/schnorr/test/fixtures/schnorr_signature_proof"
  in
  Printf.printf "dump_schnorr_signature_proof: base_dir = %s\n" base_dir ;
  (* Three deterministic (sk, msg) cases. Case 0 keeps (42, 7) so the
     existing `schnorr_signature_proof/` fixture's VK/public-input (and
     the witness-diff baseline) stay stable; cases 1,2 land in sibling
     `_2`/`_3` dirs (the caller creates them). The proof bytes differ each
     run (see `dump_case`), so re-running replaces each proof with another
     valid one. *)
  let cases =
    [ (Pallas_scalar.of_int 42, Tick_field.of_int 7, base_dir)
    ; (Pallas_scalar.of_int 43, Tick_field.of_int 11, base_dir ^ "_2")
    ; (Pallas_scalar.of_int 44, Tick_field.of_int 13, base_dir ^ "_3")
    ]
  in
  Core_kernel.List.iter cases ~f:(fun (sk, msg_field, output_dir) ->
      dump_case ~sk ~msg_field ~output_dir )
