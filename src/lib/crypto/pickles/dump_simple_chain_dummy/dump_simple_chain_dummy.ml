(** Dump Simple_chain dummy values for PureScript to hardcode.
 *
 *  This executable runs the Simple_chain compile pipeline (which advances
 *  the Ro counter state) and then calls
 *    Pickles.Proof.dummy Nat.N1.n Nat.N1.n ~domain_log2:14
 *  exactly as `dump_simple_chain.ml` does at line 90. It dumps the
 *  resulting `Proof.dummy` statement.plonk values + prev_evals to stdout
 *  so PureScript can hardcode them and produce byte-identical advice for
 *  the base-case step prover.
 *
 *  The output is consumed by the PureScript test fixture
 *  `packages/pickles-circuit-diffs/test/fixtures/simple_chain_dummy.txt`
 *  and the PureScript production module `Pickles.Dummy.SimpleChain`.
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_simple_chain_dummy/dump_simple_chain_dummy.exe \
 *      > packages/pickles-circuit-diffs/test/fixtures/simple_chain_dummy.txt
 *)

open Backend
open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

(* Inductive rule: identical to Simple_chain base case in test_no_sideloaded.ml
   and dump_simple_chain.ml. *)

type _ Snarky_backendless.Request.t +=
  | Prev_input : Tick.Field.t Snarky_backendless.Request.t
  | Proof : Pickles_types.Nat.N1.n Pickles.Proof.t Snarky_backendless.Request.t

let _handler (prev_input : Tick.Field.t)
    (proof : _ Pickles.Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Prev_input ->
      respond (Provide prev_input)
  | Proof ->
      respond (Provide proof)
  | _ ->
      respond Unhandled

let fp s v = Format.printf "%s: %s@." s (Kimchi_pasta.Pasta.Fp.to_string v)
let fq s v = Format.printf "%s: %s@." s (Kimchi_pasta.Pasta.Fq.to_string v)

let () =
  (* Run the exact same compile pipeline that dump_simple_chain.ml does.
     We throw away the provers — we only care about the side effect of
     consuming Ro calls so the subsequent Proof.dummy fires at the right
     counter state. *)
  let _tag, _, _p, _provers =
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
  (* Now the Ro state is advanced exactly as it is at dump_simple_chain.ml
     line 90 (post-compile, pre-Proof.dummy). *)
  let module Proof = Pickles__Proof in
  let (Proof.T dummy_proof) =
    Proof.dummy Pickles_types.Nat.N1.n Pickles_types.Nat.N1.n ~domain_log2:14
  in
  let plonk = dummy_proof.statement.proof_state.deferred_values.plonk in
  let module Challenge = Pickles__Import.Challenge in
  fp "simple_chain_dummy.plonk.alpha.raw"
    (Challenge.Constant.to_tick_field plonk.alpha.inner) ;
  fp "simple_chain_dummy.plonk.beta"
    (Challenge.Constant.to_tick_field plonk.beta) ;
  fp "simple_chain_dummy.plonk.gamma"
    (Challenge.Constant.to_tick_field plonk.gamma) ;
  fp "simple_chain_dummy.plonk.zeta.raw"
    (Challenge.Constant.to_tick_field plonk.zeta.inner) ;

  (* sponge_digest_before_evaluations — should be zero per proof.ml:154 *)
  let module D = Pickles__Import.Digest in
  fq "simple_chain_dummy.sponge_digest"
    (D.Constant.to_tock_field
       dummy_proof.statement.proof_state.sponge_digest_before_evaluations) ;

  (* prev_evals: tick-derived polynomial evaluations consumed by
     stepDummyUnfinalizedProofWith's expand_deferred computation. *)
  let pe = dummy_proof.prev_evals in
  fp "simple_chain_dummy.prev_evals.ft_eval1" pe.ft_eval1 ;

  let (pi_z, pi_oz) = pe.evals.public_input in
  Array.iteri pi_z ~f:(fun j v ->
      fp (Printf.sprintf "simple_chain_dummy.prev_evals.public_input.zeta.%d" j) v) ;
  Array.iteri pi_oz ~f:(fun j v ->
      fp (Printf.sprintf "simple_chain_dummy.prev_evals.public_input.omega_zeta.%d" j) v) ;

  let ev = pe.evals.evals in
  let dump_eval name (z, oz) =
    Array.iteri z ~f:(fun j v ->
        fp (Printf.sprintf "simple_chain_dummy.prev_evals.%s.zeta.%d" name j) v) ;
    Array.iteri oz ~f:(fun j v ->
        fp (Printf.sprintf "simple_chain_dummy.prev_evals.%s.omega_zeta.%d" name j) v)
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
  dump_eval "endomul_scalar_selector" ev.endomul_scalar_selector
