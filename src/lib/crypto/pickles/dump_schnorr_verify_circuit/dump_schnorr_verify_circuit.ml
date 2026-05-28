(** Dump the constraint system of Mina's production Schnorr verifier
 *  (`Signature_lib.Schnorr.Chunked.Checked.verifies`).
 *
 *  Thin wrapper — the circuit body is one call into signature_lib,
 *  with no scale/Shifted/etc. substitutions. This produces the
 *  byte-equivalent ground-truth fixture used by the PureScript
 *  `pickles-circuit-diffs` test
 *  (`schnorr_verify_step_circuit.{json,labels,gate_labels,
 *  cached_constants}`). PS iterates against this output.
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_verify_circuit/
 *              dump_schnorr_verify_circuit.exe -- <output_dir>
 *)

module Impl = Pickles.Impls.Step

(* Input layout: (public_key, signature, msg) where
 *   public_key : Inner_curve.var      = (Field, Field)
 *   signature  : Signature.var        = (Field, Scalar-as-255-bits)
 *   msg        : Field.Var.t          (we wrap it into
 *                                       Input.Chunked.field_elements
 *                                       [|msg|] inside the circuit). *)
let schnorr_verify_circuit
    ( ( public_key
      , signature
      , (msg : Snark_params.Tick.Field.Var.t) )
      : Snark_params.Tick.Inner_curve.var
        * Signature_lib.Schnorr.Chunked.Signature.var
        * Snark_params.Tick.Field.Var.t ) () =
  Impl.run_checked
    Snark_params.Tick.Checked.(
      let%bind (module S) =
        Snark_params.Tick.Inner_curve.Checked.Shifted.create ()
      in
      let m =
        Random_oracle_input.Chunked.field_elements [| msg |]
      in
      Signature_lib.Schnorr.Chunked.Checked.verifies
        ~signature_kind:Mina_signature_kind.Mainnet
        (module S)
        signature public_key m)

let input_typ =
  Snark_params.Tick.Typ.tuple3
    Snark_params.Tick.Inner_curve.typ
    Signature_lib.Schnorr.Chunked.Signature.typ
    Snark_params.Tick.Field.typ

let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/pickles-circuit-diffs/circuits/ocaml"
  in
  Printf.printf "dump_schnorr_verify_circuit: output_dir = %s\n" output_dir ;
  Pickles.Dump_circuit_impl.dump_tick_with_labels output_dir
    "schnorr_verify_step_circuit"
    schnorr_verify_circuit
    ~input_typ ~return_typ:Snark_params.Tick.Boolean.typ
