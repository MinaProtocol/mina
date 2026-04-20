(** Standalone runner that exercises the Tree_proof_return base case.
 *
 *  Verbatim translation of the inductive rule from
 *  `mina/src/lib/crypto/pickles/test/test_no_sideloaded.ml:315-429`.
 *  Tree_proof_return is the first HETEROGENEOUS-PREV target in our
 *  convergence loop: `prevs = [No_recursion_return.tag; self]` with
 *  per-slot `max_proofs_verified = [N0; N2]`, Output mode, and
 *  `override_wrap_domain:N1` giving self's wrap_domains.h = 2^14.
 *
 *  Structure:
 *    1. Compile No_recursion_return (leaf rule, N0). Prove `example`
 *       once — we reuse that proof for slot 0 across all subsequent
 *       Tree_proof_return step calls.
 *    2. Compile Tree_proof_return (N2) with No_recursion_return.tag in
 *       its prevs list.
 *    3. Run Tree_proof_return's base case (b0, is_base_case=true):
 *       slot 0 = real No_recursion_return proof (always verified),
 *       slot 1 = dummy N2 proof at domain_log2=15 (not verified).
 *    4. Verify b0.
 *
 *  Trace emission: the Pickles library itself emits structured trace
 *  lines via `Pickles_trace.{tick_field,tock_field,string}` at every
 *  key computation (sponge digests, oracle outputs, step proof PI,
 *  wrap proof PI, etc.). This binary just sets up the prover call;
 *  the trace file is written as a side effect of proving.
 *
 *  This is the OCaml side of the Tree_proof_return byte-identical
 *  trace convergence loop. The PureScript-side analog lives at
 *  `packages/pickles/test/Test/Pickles/Prove/TreeProofReturn.purs`.
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

(* ========================================================================
 *  Rule 1: No_recursion_return (leaf, N0, Output mode, always returns 0)
 *  Identical to test_no_sideloaded.ml:89-126.
 * ======================================================================== *)

module No_recursion_return = struct
  let tag, _, p, Pickles.Provers.[ step ] =
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

  module Proof = (val p)

  (* Produce and verify a real No_recursion_return proof. We reuse
   * this proof as slot 0's witness in every Tree_proof_return step. *)
  let example =
    let res, (), b0 =
      Promise.block_on_async_exn (fun () -> step ())
    in
    assert (Impls.Step.Field.Constant.(equal zero) res) ;
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (res, b0) ] ) ) ;
    (res, b0)
end

(* ========================================================================
 *  Rule 2: Tree_proof_return (N2, Output mode, heterogeneous prevs)
 *  Identical to test_no_sideloaded.ml:315-392.
 * ======================================================================== *)

type _ Snarky_backendless.Request.t +=
  | Is_base_case : bool Snarky_backendless.Request.t
  | No_recursion_input : Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | No_recursion_proof :
      Pickles_types.Nat.N0.n Pickles.Proof.t Snarky_backendless.Request.t
  | Recursive_input : Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | Recursive_proof :
      Pickles_types.Nat.N2.n Pickles.Proof.t Snarky_backendless.Request.t

let handler (is_base_case : bool)
    ((no_recursion_input, no_recursion_proof) :
      Impls.Step.Field.Constant.t * _ Pickles.Proof.t )
    ((recursion_input, recursion_proof) :
      Impls.Step.Field.Constant.t * _ Pickles.Proof.t )
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Is_base_case ->
      respond (Provide is_base_case)
  | No_recursion_input ->
      respond (Provide no_recursion_input)
  | No_recursion_proof ->
      respond (Provide no_recursion_proof)
  | Recursive_input ->
      respond (Provide recursion_input)
  | Recursive_proof ->
      respond (Provide recursion_proof)
  | _ ->
      respond Unhandled

let () =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise () ~public_input:(Output Impls.Step.Field.typ)
      ~override_wrap_domain:Pickles_base.Proofs_verified.N1
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N2)
      ~name:"tree_proof_return"
      ~choices:(fun ~self ->
        [ { identifier = "main"
          ; feature_flags = Plonk_types.Features.none_bool
          ; prevs = [ No_recursion_return.tag; self ]
          ; main =
              (fun { public_input = () } ->
                let no_recursive_input =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      No_recursion_input )
                in
                let no_recursive_proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> No_recursion_proof)
                in
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      Recursive_input )
                in
                let prev_proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Recursive_proof)
                in
                let is_base_case =
                  Impls.Step.exists Impls.Step.Boolean.typ ~request:(fun () ->
                      Is_base_case )
                in
                let proof_must_verify = Impls.Step.Boolean.not is_base_case in
                let self_out =
                  Impls.Step.Field.(
                    if_ is_base_case ~then_:zero ~else_:(one + prev))
                in
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements =
                      [ { public_input = no_recursive_input
                        ; proof = no_recursive_proof
                        ; proof_must_verify = Impls.Step.Boolean.true_
                        }
                      ; { public_input = prev
                        ; proof = prev_proof
                        ; proof_must_verify
                        }
                      ]
                  ; public_output = self_out
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in
  Pickles.Pickles_trace.string "tree_proof_return.begin" "base_case" ;
  (* Base case: slot 0 = real No_recursion_return proof (always
   * verified); slot 1 = dummy N2 proof (proof_must_verify=false). *)
  let s_neg_one = Impls.Step.Field.Constant.(negate one) in
  let module PickProof = Pickles__Proof in
  let b_neg_one_internal =
    PickProof.dummy Nat.N2.n Nat.N2.n ~domain_log2:15
  in
  (* `Pickles.Proof.t` is a wire-type alias over `Pickles__Proof.t` —
   * same underlying representation, re-exported through
   * `Wire_types.Types.S`. Cast so we can both dump internal fields
   * (via PickProof.T pattern) AND pass to the step handler (which
   * expects the wire-type). *)
  let b_neg_one : Nat.N2.n Pickles.Proof.t =
    Obj.magic b_neg_one_internal
  in
  (* Dump Proof.dummy field values so PureScript can hardcode them in
   * `Pickles.Dummy.Tree` for byte-identical slot-1 advice. Mirrors
   * `dump_simple_chain_dummy.ml` but for Tree's post-compile Ro state. *)
  ( let (PickProof.T dp) = b_neg_one_internal in
    let plonk = dp.statement.proof_state.deferred_values.plonk in
    Pickles.Pickles_trace.tick_field "tree_dummy.plonk.alpha.raw"
      (Pickles__Import.Challenge.Constant.to_tick_field plonk.alpha.inner) ;
    Pickles.Pickles_trace.tick_field "tree_dummy.plonk.beta"
      (Pickles__Import.Challenge.Constant.to_tick_field plonk.beta) ;
    Pickles.Pickles_trace.tick_field "tree_dummy.plonk.gamma"
      (Pickles__Import.Challenge.Constant.to_tick_field plonk.gamma) ;
    Pickles.Pickles_trace.tick_field "tree_dummy.plonk.zeta.raw"
      (Pickles__Import.Challenge.Constant.to_tick_field plonk.zeta.inner) ;
    Pickles.Pickles_trace.tock_field "tree_dummy.sponge_digest"
      (Pickles__Import.Digest.Constant.to_tock_field
         dp.statement.proof_state.sponge_digest_before_evaluations) ;
    let pe = dp.prev_evals in
    Pickles.Pickles_trace.tick_field "tree_dummy.prev_evals.ft_eval1" pe.ft_eval1 ;
    let pi_z, pi_oz = pe.evals.public_input in
    Array.iteri pi_z ~f:(fun j v ->
        Pickles.Pickles_trace.tick_field
          (Printf.sprintf "tree_dummy.prev_evals.public_input.zeta.%d" j) v) ;
    Array.iteri pi_oz ~f:(fun j v ->
        Pickles.Pickles_trace.tick_field
          (Printf.sprintf "tree_dummy.prev_evals.public_input.omega_zeta.%d" j) v) ;
    let ev = pe.evals.evals in
    let dump_eval name (z, oz) =
      Array.iteri z ~f:(fun j v ->
          Pickles.Pickles_trace.tick_field
            (Printf.sprintf "tree_dummy.prev_evals.%s.zeta.%d" name j) v) ;
      Array.iteri oz ~f:(fun j v ->
          Pickles.Pickles_trace.tick_field
            (Printf.sprintf "tree_dummy.prev_evals.%s.omega_zeta.%d" name j) v)
    in
    let dump_eval_vec name vec =
      Array.iteri (Pickles_types.Vector.to_array vec) ~f:(fun i pair ->
          dump_eval (Printf.sprintf "%s.%d" name i) pair)
    in
    dump_eval_vec "w" ev.w ;
    dump_eval_vec "coefficients" ev.coefficients ;
    dump_eval "z" ev.z ;
    dump_eval_vec "s" ev.s ;
    dump_eval "generic_selector" ev.generic_selector ;
    dump_eval "poseidon_selector" ev.poseidon_selector ;
    dump_eval "complete_add_selector" ev.complete_add_selector ;
    dump_eval "mul_selector" ev.mul_selector ;
    dump_eval "emul_selector" ev.emul_selector ;
    dump_eval "endomul_scalar_selector" ev.endomul_scalar_selector ) ;
  let s0, (), b0 =
    Promise.block_on_async_exn (fun () ->
        step
          ~handler:
            (handler true No_recursion_return.example (s_neg_one, b_neg_one))
          () )
  in
  assert (Impls.Step.Field.Constant.(equal zero) s0) ;
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s0, b0) ])) ;
  Pickles.Pickles_trace.string "tree_proof_return.end" "base_case_verified"
