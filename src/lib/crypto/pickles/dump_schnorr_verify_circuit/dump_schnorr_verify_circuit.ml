(** Dump the constraint system of Mina's production Schnorr verifier
 *  (`Signature_lib.Schnorr.Chunked.Checked.verifies`).
 *
 *  Thin exe — circuit body, input typ, return typ all live in
 *  `Dump_schnorr_circuit_lib`, shared with `dump_schnorr_signature_proof/`.
 *
 *  Output: `schnorr_verify_step_circuit.{json,labels,gate_labels,
 *           cached_constants}` in `<output_dir>` (consumed by
 *  `packages/pickles-circuit-diffs/`).
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_verify_circuit/
 *              dump_schnorr_verify_circuit.exe -- <output_dir>
 *)

let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/pickles-circuit-diffs/circuits/ocaml"
  in
  Printf.printf "dump_schnorr_verify_circuit: output_dir = %s\n" output_dir ;
  Pickles.Dump_circuit_impl.dump_tick_with_labels output_dir
    "schnorr_verify_step_circuit"
    Dump_schnorr_circuit_lib.schnorr_verify_circuit
    ~input_typ:Dump_schnorr_circuit_lib.input_typ
    ~return_typ:Dump_schnorr_circuit_lib.return_typ
