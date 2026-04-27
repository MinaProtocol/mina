(** Standalone runner that exercises the multi-branch (= multi-rule
 *  in one [Pickles.compile_promise]) feature in its minimal form.
 *
 *  TWO rules share ONE wrap verification key:
 *
 *    Rule 0 ("make_zero"):
 *      - public_input = Field.t
 *      - prevs = []
 *      - body asserts public_input = 0
 *
 *    Rule 1 ("increment"):
 *      - public_input = Field.t
 *      - prevs = [self]
 *      - body asserts public_input = prev + 1, verifies prev
 *
 *  The [self] in increment.prevs resolves to ANY branch at proof
 *  time (Pickles' multi-branch [whichBranch] dispatch). This binary
 *  exercises both:
 *
 *    b0 = make_zero ()                    -- branch 0 (no prev)
 *    b1 = increment ~prev:b0 1            -- prev branch = 0
 *    b2 = increment ~prev:b1 2            -- prev branch = 1
 *
 *  Verifying b0 (make_zero), b1 (increment of make_zero), and b2
 *  (increment of increment) ALL use the same wrap VK. That's the
 *  feature.
 *
 *  This fixture is the minimal version of the
 *  [Transaction_snark.Merge.rule] / [multisig_account.ml] dummy-rule
 *  patterns — it strips away every Mina-specific dependency
 *  (Statement.With_sok, Schnorr signatures, M-of-N predicates, zkApp
 *  command flavors) and keeps only the pure Pickles multi-branch
 *  shape. PureScript's
 *  [Pickles.Prove.Compile] currently supports only one rule per
 *  [compile] call, so the byte-comparison target here will fail
 *  until multi-branch is added on the PS side.
 *
 *  References:
 *    - test_no_sideloaded.ml only contains single-rule ~choices
 *      lists; this fixture is the smallest multi-branch example
 *      anywhere in the Pickles test surface.
 *    - transaction_snark.ml:3315-3342 for [Merge.rule] (real-world
 *      multi-branch usage with [prevs = [self; self]]).
 *    - multisig_account.ml:222-267 for the dummy-padding multi-branch
 *      pattern.
 *
 *  PureScript-side analog (TBD when multi-branch lands):
 *    [packages/pickles/test/Test/Pickles/Prove/TwoPhaseChain.purs]
 *
 *  Required env vars at runtime:
 *  - [PICKLES_TRACE_FILE] — path to write the trace log (overwritten).
 *  - [KIMCHI_DETERMINISTIC_SEED] — u64 seed for the patched
 *    ChaCha20Rng in kimchi-stubs. Required (panics if unset) so the
 *    proof is bit-identical across runs and across PureScript.
 *  - [KIMCHI_WITNESS_DUMP] (optional) — path template like
 *    [witness%c.txt] for per-call witness dumps consumed by
 *    [tools/witness_diff.sh].
 *)

open Backend
open Pickles_types

(* URS info — required before any Pickles.compile call. Mirrors
 * test_no_sideloaded.ml's setup. *)
let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

(* Request handler shared between rules: increment needs to read its
 * prev (input + proof), make_zero has no prevs and ignores it. *)
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
  let _tag, _, p, Pickles.Provers.[ make_zero; increment ] =
    Pickles.compile_promise ()
      ~public_input:(Input Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
      (* N1 = max over all rules' prev counts. make_zero has 0 prevs,
       * increment has 1, so the shared wrap VK is sized for 1. *)
      ~max_proofs_verified:(module Nat.N1)
      ~name:"two_phase_chain"
      ~choices:(fun ~self ->
        [ { identifier = "make_zero"
          ; prevs = []
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self_v } ->
                Impls.Step.Field.Assert.equal self_v Impls.Step.Field.zero ;
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements = []
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
          }
        ; { identifier = "increment"
          ; prevs = [ self ] (* self = ANY branch of this proof system *)
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self_v } ->
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ
                    ~request:(fun () -> Prev_input)
                in
                let proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Proof)
                in
                Impls.Step.Field.(Assert.equal self_v (one + prev)) ;
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements =
                      [ { public_input = prev
                        ; proof
                        ; proof_must_verify = Impls.Step.Boolean.true_
                        }
                      ]
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in

  (* === Branch 0: make_zero. No prev. public_input = 0. === *)
  Pickles.Pickles_trace.string "two_phase_chain.begin" "make_zero" ;
  let (), (), b0 =
    Promise.block_on_async_exn (fun () -> make_zero Tick.Field.zero)
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.zero, b0) ] ) ) ;
  Pickles.Pickles_trace.string "two_phase_chain.end" "make_zero_verified" ;

  (* === Branch 1: increment, with prev = b0 (a make_zero proof).
   *   public_input = 1, asserts 1 = 0 + 1 (prev = 0).
   *
   *   Crucial multi-branch bit: increment's wrap circuit verifies a
   *   make_zero proof under the SAME wrap VK that produced it. The
   *   whichBranch field in the wrap statement tells the verifier the
   *   prev was produced by branch 0. === *)
  Pickles.Pickles_trace.string "two_phase_chain.begin" "increment_b1" ;
  let (), (), b1 =
    Promise.block_on_async_exn (fun () ->
        increment ~handler:(handler Tick.Field.zero b0) Tick.Field.one )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.one, b1) ] ) ) ;
  Pickles.Pickles_trace.string "two_phase_chain.end" "increment_b1_verified" ;

  (* === Branch 1 again: increment, with prev = b1 (an increment proof).
   *   public_input = 2, asserts 2 = 1 + 1 (prev = 1).
   *
   *   This time the prev is from branch 1 — same proof system, same
   *   wrap VK, different whichBranch value. Demonstrates that
   *   self-resolves-to-any-branch is fully dynamic at proof time. === *)
  Pickles.Pickles_trace.string "two_phase_chain.begin" "increment_b2" ;
  let (), (), b2 =
    Promise.block_on_async_exn (fun () ->
        increment ~handler:(handler Tick.Field.one b1) Tick.Field.(of_int 2) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.(of_int 2), b2) ] ) ) ;
  Pickles.Pickles_trace.string "two_phase_chain.end" "increment_b2_verified"
