(** Standalone runner that exercises only the No_recursion_return base case.
 *
 *  Verbatim translation of the No_recursion_return module from
 *  `mina/src/lib/crypto/pickles/test/test_no_sideloaded.ml:89-126` —
 *  same single-rule compile, same `public_output = Field.zero`,
 *  same `Pickles.compile_promise` invocation at N=0 Output mode.
 *
 *  We run JUST the single proof (there's no chain — N=0 has no
 *  prev proofs, so each `step ()` call is a fresh base-case-like
 *  proof). The trace file produced by `Pickles_trace` contains the
 *  entries for that one step proof and nothing else.
 *
 *  This binary is the OCaml side of the No_recursion_return
 *  byte-identical pickles trace reproduction loop — the first rung
 *  of the Tree_proof_return proof-level ladder. Tree_proof_return's
 *  slot 0 consumes a real No_recursion_return proof, so we need
 *  byte-for-byte parity here before we can produce that input on
 *  the PS side.
 *
 *  PureScript-side analog:
 *    `packages/pickles/test/Test/Pickles/Prove/NoRecursionReturn.purs`
 *
 *  Required env vars at runtime:
 *  - `PICKLES_TRACE_FILE` — path to write the trace log (overwritten).
 *  - `KIMCHI_DETERMINISTIC_SEED` — u64 seed for the patched ChaCha20Rng
 *    in kimchi-stubs. Required (panics if unset) so the proof is
 *    bit-identical across runs and across PureScript.
 *)

open Pickles_types

(* URS info — required before any Pickles.compile call, otherwise the
 * dlog keypair setup raises [Dlog_based.urs: Info not set]. *)
let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise () ~public_input:(Output Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~name:"no_recursion_return"
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun _ ->
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements = []
                  ; public_output = Impls.Step.Field.zero
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in
  Pickles.Pickles_trace.string "no_recursion_return.begin" "base_case" ;
  let s0, (), b0 =
    Promise.block_on_async_exn (fun () -> step ())
  in
  assert (Impls.Step.Field.Constant.(equal zero) s0) ;
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s0, b0) ])) ;
  Pickles.Pickles_trace.string "no_recursion_return.end" "base_case_verified"
