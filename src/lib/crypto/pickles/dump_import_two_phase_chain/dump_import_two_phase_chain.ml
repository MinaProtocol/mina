(** Compile-only driver for an [External] slot whose import has several
 *  step domains, beside a [self] slot: the blockchain shape.
 *
 *  1. Compile [two_phase_chain], exactly as [dump_two_phase_chain]
 *     does: [make_zero] (no prevs) and [increment] (prevs = [self]),
 *     whose step domains differ.
 *  2. Compile [import_two_phase_chain]: one rule, N2, Output mode,
 *     [prevs = [Two_phase_chain.tag; self]] and
 *     [override_wrap_domain:N1]. Slot 0's finalize dispatches over
 *     [two_phase_chain]'s step domains ([domain_for_compiled]); slot 1
 *     is this system's previous proof, verified unless the base case.
 *     The state is the transaction's value in the base case, the
 *     previous state plus it otherwise.
 *
 *  Compiling builds the keys lazily, so each system's verification key
 *  is forced, [two_phase_chain]'s first. With [PICKLES_STEP_CS_DUMP]
 *  set, step CS 2 is then the chain's step circuit,
 *  [step_main_import_two_phase_chain_circuit]. The PureScript analog is
 *  [Test.Pickles.Prove.ImportTwoPhaseChain].
 *)

open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

type _ Snarky_backendless.Request.t +=
  | Prev_input : Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | Proof : Nat.N1.n Pickles.Proof.t Snarky_backendless.Request.t

(* [dump_two_phase_chain]'s system, verbatim. *)
module Two_phase_chain = struct
  let tag, _, p, Pickles.Provers.[ _make_zero; _increment ] =
    Pickles.compile_promise () ~public_input:(Input Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
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
          ; prevs = [ self ]
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self_v } ->
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      Prev_input )
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

  module Proof = (val p)

  let () =
    ignore
      ( Promise.block_on_async_exn (fun () ->
            Lazy.force Proof.verification_key_promise )
        : Pickles.Verification_key.t )
end

type _ Snarky_backendless.Request.t +=
  | Tx_input : Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | Tx_proof : Nat.N1.n Pickles.Proof.t Snarky_backendless.Request.t
  | Prev_state : Impls.Step.Field.Constant.t Snarky_backendless.Request.t
  | Prev_proof : Nat.N2.n Pickles.Proof.t Snarky_backendless.Request.t
  | Is_base_case : bool Snarky_backendless.Request.t

let () =
  let _tag, _, p, Pickles.Provers.[ _step ] =
    Pickles.compile_promise () ~public_input:(Output Impls.Step.Field.typ)
      ~override_wrap_domain:Pickles_base.Proofs_verified.N1
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N2)
      ~name:"import_two_phase_chain"
      ~choices:(fun ~self ->
        [ { identifier = "main"
          ; feature_flags = Plonk_types.Features.none_bool
          ; prevs = [ Two_phase_chain.tag; self ]
          ; main =
              (fun { public_input = () } ->
                let tx =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      Tx_input )
                in
                let tx_proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Tx_proof)
                in
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      Prev_state )
                in
                let prev_proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Prev_proof)
                in
                let is_base_case =
                  Impls.Step.exists Impls.Step.Boolean.typ ~request:(fun () ->
                      Is_base_case )
                in
                let proof_must_verify = Impls.Step.Boolean.not is_base_case in
                let self_out =
                  Impls.Step.Field.(
                    if_ is_base_case ~then_:tx ~else_:(prev + tx))
                in
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements =
                      [ { public_input = tx
                        ; proof = tx_proof
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
  ignore
    ( Promise.block_on_async_exn (fun () ->
          Lazy.force Proof.verification_key_promise )
      : Pickles.Verification_key.t ) ;
  print_endline "compiled two_phase_chain and import_two_phase_chain"
