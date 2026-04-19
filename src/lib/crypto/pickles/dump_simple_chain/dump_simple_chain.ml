(** Standalone runner that exercises only the Simple_chain base case.
 *
 *  Verbatim translation of the inductive rule from
 *  `mina/src/lib/crypto/pickles/test/test_no_sideloaded.ml:128-186` —
 *  same `prev + 1` rule, same `Pickles_types.Nat.N1` max_proofs_verified,
 *  same `Pickles.compile_promise` invocation, same dummy proof at
 *  domain_log2=14. The only deviation: we run JUST the base case (b0)
 *  and exit, so the trace file produced by `Pickles_trace` contains only
 *  the entries for that one step proof and nothing else.
 *
 *  This binary is the OCaml side of the byte-identical pickles trace
 *  reproduction loop. The PureScript-side analog is at
 *  `packages/pickles/test/Test/Pickles/Prove/SimpleChain.purs` (TODO,
 *  Task #65).
 *
 *  Required env vars at runtime:
 *  - `PICKLES_TRACE_FILE` — path to write the trace log (overwritten).
 *  - `KIMCHI_DETERMINISTIC_SEED` — u64 seed for the patched ChaCha20Rng
 *    in kimchi-stubs. Required (panics if unset) so the proof is
 *    bit-identical across runs and across PureScript.
 *)

open Backend
open Pickles_types

(* URS info — required before any Pickles.compile call, otherwise the
 * dlog keypair setup raises [Dlog_based.urs: Info not set]. We pass an
 * empty spec list (= no override), letting the backend load the default
 * URS cache. Mirrors test_no_sideloaded.ml lines 12-14. *)
let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

(* Inductive rule: identical to test_no_sideloaded.ml Simple_chain. *)

type _ Snarky_backendless.Request.t +=
  | Prev_input : Tick.Field.t Snarky_backendless.Request.t
  | Proof : Pickles_types.Nat.N1.n Pickles.Proof.t Snarky_backendless.Request.t

let handler (prev_input : Tick.Field.t)
    (proof : _ Pickles.Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Prev_input ->
      respond (Provide prev_input)
  | Proof ->
      respond (Provide proof)
  | _ ->
      respond Unhandled

let () =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise ()
      ~public_input:(Input Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N1)
      ~name:"blockchain-snark"
      ~choices:(fun ~self ->
        [ { identifier = "main"
          ; prevs = [ self ]
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self } ->
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ
                    ~request:(fun () -> Prev_input)
                in
                let proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Proof)
                in
                let is_base_case = Impls.Step.Field.equal Impls.Step.Field.zero self in
                let proof_must_verify = Impls.Step.Boolean.not is_base_case in
                let self_correct =
                  Impls.Step.Field.(equal (one + prev) self)
                in
                Impls.Step.Boolean.Assert.any [ self_correct; is_base_case ] ;
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements =
                      [ { public_input = prev; proof; proof_must_verify } ]
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in
  Pickles.Pickles_trace.string "simple_chain.begin" "base_case" ;
  let s_neg_one = Tick.Field.(negate one) in
  let b_neg_one : Nat.N1.n Pickles.Proof.t =
    Pickles.Proof.dummy Nat.N1.n Nat.N1.n ~domain_log2:14
  in
  let (), (), b0 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler s_neg_one b_neg_one) Tick.Field.zero )
  in
  (* Verify the produced proof to confirm end-to-end correctness;
   * tracing only fires on the prover side, so verification adds no
   * trace lines but exercises the same kimchi machinery. *)
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.zero, b0) ] ) ) ;
  Pickles.Pickles_trace.string "simple_chain.end" "base_case_verified" ;
  (* === Inductive case (b1): self=1, prev=0, verifying b0 === *)
  Pickles.Pickles_trace.string "simple_chain.begin" "inductive_case" ;
  let (), (), b1 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler Tick.Field.zero b0) Tick.Field.one )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.one, b1) ] ) ) ;
  Pickles.Pickles_trace.string "simple_chain.end" "inductive_case_verified" ;
  (* === Inductive case b2: self=2, prev=1, verifying b1 === *)
  Pickles.Pickles_trace.string "simple_chain.begin" "inductive_case_b2" ;
  let (), (), b2 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler Tick.Field.one b1) Tick.Field.(of_int 2) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.(of_int 2), b2) ] ) ) ;
  Pickles.Pickles_trace.string "simple_chain.end" "inductive_case_b2_verified"
