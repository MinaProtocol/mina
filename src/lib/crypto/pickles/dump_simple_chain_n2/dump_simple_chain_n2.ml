(** Standalone runner that exercises the Simple_chain N2 base case.
 *
 *  Same shape as `dump_simple_chain` but with `max_proofs_verified = N2`
 *  and two self-recursive prev slots (`prevs = [self; self]`), mirroring
 *  the `step_main_simple_chain_n2` test scenario. The CS produced here
 *  is what `pickles-circuit-diffs/circuits/ocaml/step_main_simple_chain_n2_circuit.json`
 *  and `wrap_main_n2_circuit.json` should contain (via
 *  `tools/regen_top_level_fixtures.sh` + `PICKLES_STEP_CS_DUMP` /
 *  `PICKLES_WRAP_CS_DUMP`).
 *
 *  Rule body: `1 + prev1 + prev2 = self` (with `is_base_case` short-
 *  circuit when `self = 0`). Mirrors the deleted
 *  `step_main_simple_chain_n2` helper that previously lived in
 *  `dump_circuit_impl.ml` (removed because its inline rule rewrite
 *  diverged from the production rule shape).
 *
 *  Required env vars:
 *  - [KIMCHI_DETERMINISTIC_SEED] — u64 seed for the patched ChaCha20Rng.
 *  - [PICKLES_STEP_CS_DUMP] / [PICKLES_WRAP_CS_DUMP] — optional fixture
 *    dump paths (stem template, `%c` substituted with monotonic counter).
 *)

open Backend
open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

(* Two requests — one per prev slot. Each carries the prev's input
   field + the corresponding wrapped proof. Mirrors `dump_simple_chain`
   but doubled to match `prevs = [self; self]`. *)
type _ Snarky_backendless.Request.t +=
  | Prev1_input : Tick.Field.t Snarky_backendless.Request.t
  | Proof1 : Pickles_types.Nat.N2.n Pickles.Proof.t Snarky_backendless.Request.t
  | Prev2_input : Tick.Field.t Snarky_backendless.Request.t
  | Proof2 : Pickles_types.Nat.N2.n Pickles.Proof.t Snarky_backendless.Request.t

let handler (prev1_input : Tick.Field.t) (proof1 : _ Pickles.Proof.t)
    (prev2_input : Tick.Field.t) (proof2 : _ Pickles.Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Prev1_input ->
      respond (Provide prev1_input)
  | Proof1 ->
      respond (Provide proof1)
  | Prev2_input ->
      respond (Provide prev2_input)
  | Proof2 ->
      respond (Provide proof2)
  | _ ->
      respond Unhandled

let () =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise ()
      ~public_input:(Input Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N2)
      ~override_wrap_domain:Pickles_base.Proofs_verified.N1
      ~name:"simple-chain-n2"
      ~choices:(fun ~self ->
        [ { identifier = "main"
          ; prevs = [ self; self ]
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self_input } ->
                let prev1 =
                  Impls.Step.exists Impls.Step.Field.typ
                    ~request:(fun () -> Prev1_input)
                in
                let proof1 =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Proof1)
                in
                let prev2 =
                  Impls.Step.exists Impls.Step.Field.typ
                    ~request:(fun () -> Prev2_input)
                in
                let proof2 =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Proof2)
                in
                let is_base_case =
                  Impls.Step.Field.equal Impls.Step.Field.zero self_input
                in
                let proof_must_verify = Impls.Step.Boolean.not is_base_case in
                let self_correct =
                  Impls.Step.Field.(equal (one + prev1 + prev2) self_input)
                in
                Impls.Step.Boolean.Assert.any [ self_correct; is_base_case ] ;
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements =
                      [ { public_input = prev1
                        ; proof = proof1
                        ; proof_must_verify
                        }
                      ; { public_input = prev2
                        ; proof = proof2
                        ; proof_must_verify
                        }
                      ]
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in
  ignore p ;
  (* Drive the base case (self = 0). The CS dumps fire DURING compile
     (well before this prove call), so the fixtures are already on
     disk by the time we get here.

     The prove itself is expected to RAISE: with `is_base_case = true`
     and dummy prev proofs, the constraint system on the recursive
     `proof_must_verify` slots can't actually be satisfied (the dummy
     prev's wrap proof fails to verify in-circuit). We catch and
     ignore so the driver still exits 0 — the fixtures are what we
     care about. *)
  let s_neg_one = Tick.Field.(negate one) in
  let b_dummy : Nat.N2.n Pickles.Proof.t =
    Pickles.Proof.dummy Nat.N2.n Nat.N2.n ~domain_log2:14
  in
  ( try
      let (), (), _b0 =
        Promise.block_on_async_exn (fun () ->
            step
              ~handler:(handler s_neg_one b_dummy s_neg_one b_dummy)
              Tick.Field.zero )
      in
      ()
    with _ -> () )
