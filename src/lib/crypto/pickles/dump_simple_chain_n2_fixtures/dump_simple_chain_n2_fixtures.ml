(** Witness-dump driver for the Simple_chain N2 application — the
 *  INDUCTIVE case (`prevs = [self; self]`, `max_proofs_verified = N2`,
 *  `override_wrap_domain = N1`).
 *
 *  Same rule as `dump_simple_chain_n2.ml` (`self = 1 + prev1 + prev2`,
 *  with an `is_base_case` short-circuit when `self = 0`), but this driver
 *  PROVES the full b0..b2 chain (modelled on `dump_simple_chain.ml`'s N1
 *  driver) rather than only the base case, so the kimchi
 *  `KIMCHI_WITNESS_DUMP` hook emits one witness file per step/wrap proof.
 *
 *  Drives exactly the PureScript `Test.Pickles.Prove.SimpleChainN2` chain:
 *    b0 = step(self=0)             two dummy prevs (base case)
 *    b1 = step(self=1)             verifies [b0, b0]   (1 + 0 + 0 = 1)
 *    b2 = step(self=2)             verifies [b1, b0]   (1 + 1 + 0 = 2)
 *
 *  Required env: [KIMCHI_DETERMINISTIC_SEED], [KIMCHI_WITNESS_DUMP]
 *  (`%c` = monotonic counter → b0_step b0_wrap b1_step b1_wrap b2_step
 *  b2_wrap).
 *)

open Backend
open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

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
  (* Dummy N2 prev for the base case (matches the PureScript BasePrev). *)
  let b_dummy : Nat.N2.n Pickles.Proof.t =
    Pickles.Proof.dummy Nat.N2.n Nat.N2.n ~domain_log2:15
  in
  (* === b0: self = 0, two dummy prevs (base case) === *)
  let (), (), b0 =
    Promise.block_on_async_exn (fun () ->
        step
          ~handler:(handler Tick.Field.zero b_dummy Tick.Field.zero b_dummy)
          Tick.Field.zero )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.zero, b0) ] ) ) ;
  (* === b1: self = 1, verifies [b0, b0] (1 + 0 + 0 = 1) === *)
  let (), (), b1 =
    Promise.block_on_async_exn (fun () ->
        step
          ~handler:(handler Tick.Field.zero b0 Tick.Field.zero b0)
          Tick.Field.one )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.one, b1) ] ) ) ;
  (* === b2: self = 2, verifies [b1, b0] (1 + 1 + 0 = 2) === *)
  let (), (), b2 =
    Promise.block_on_async_exn (fun () ->
        step
          ~handler:(handler Tick.Field.one b1 Tick.Field.zero b0)
          Tick.Field.(of_int 2) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.(of_int 2), b2) ] ) ) ;
  ignore b2
