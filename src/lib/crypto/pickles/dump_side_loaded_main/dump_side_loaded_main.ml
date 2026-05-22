(** Standalone reference for Pickles side-loaded recursion.
 *
 *  This is a verbatim lift of the side-loaded `Simple_chain` example
 *  from `mina/src/lib/crypto/pickles/pickles.ml:1479-1718` (the
 *  `let%test_module "domain too small"` block) into a standalone
 *  executable, so we can run it under `dune exec` and add CS / witness
 *  dumping in follow-up steps via the existing dump infrastructure.
 *
 *  Shape:
 *    - Child = `No_recursion` (mpv = N0, public input Field, asserts
 *      `self = 0`).
 *    - Side-loaded tag with `max_proofs_verified = N2` (the side-tag's
 *      upper bound; the actual child has mpv N0).
 *    - Main = `Simple_chain` (mpv = N1, public input Field) whose
 *      single `prevs` slot is the side-loaded tag. Inside main we
 *      `exists` the VK as a prover-value, bind it via
 *      `Side_loaded.in_prover` (deferred via `as_prover`) and
 *      `Side_loaded.in_circuit`, and assert the increment relation
 *      `prev + 1 = self`.
 *    - Drives one proof: `step Field.Constant.one` with handler
 *      providing (prev_input = 0, child b0 wrapped via
 *      `Side_loaded.Proof.of_proof`, child's side-loaded VK).
 *
 *  Optional env vars at runtime:
 *  - [KIMCHI_DETERMINISTIC_SEED] — u64 seed for the patched
 *    ChaCha20Rng in kimchi-stubs. Set this (e.g. to [42]) so the
 *    witness/proof output is bit-identical across runs and
 *    cross-implementation.
 *  - [KIMCHI_WITNESS_DUMP] — path template like
 *    [/tmp/witness_sl_%c.txt]. Each kimchi prover emit dumps the
 *    full (public + advice) witness matrix. The [%c] placeholder is
 *    substituted with a monotonically incrementing counter:
 *      0 = child no_recursion step    (d1_size=512,   public=1)
 *      1 = child no_recursion wrap    (d1_size=8192,  public=40)
 *      2 = main side-loaded step      (d1_size=16384, public=34)
 *      3 = main side-loaded wrap      (d1_size=16384, public=40)
 *    Use [tools/witness_diff.sh] to compare against PS-side dumps.
 *)

open Pickles
open Pickles_types
open Impls.Step

let () = Backend.Tock.Keypair.set_urs_info []
let () = Backend.Tick.Keypair.set_urs_info []

(* Currently, a circuit must have at least 1 of every type of
   constraint. Mirrors `pickles.ml:1483-1508`. *)
let dummy_constraints () =
  Impl.(
    let x =
      exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
    in
    let g =
      exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
          Backend.Tick.Inner_curve.(to_affine_exn one) )
    in
    ignore
      ( Scalar_challenge.to_field_checked'
          (module Impl)
          ~num_bits:16
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t * Field.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t ))

module No_recursion = struct
  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N0)
          ~name:"side_loaded_child__no_recursion"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    dummy_constraints () ;
                    Field.Assert.equal self Field.zero ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements = []
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let (), (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    (Field.Constant.zero, b0)

  let example_input, example_proof = example
end

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input : Field.Constant.t Snarky_backendless.Request.t
    | Proof : Side_loaded.Proof.t Snarky_backendless.Request.t
    | Verifier_index :
        Side_loaded.Verification_key.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
      (verifier_index : Side_loaded.Verification_key.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | Verifier_index ->
        respond (Provide verifier_index)
    | _ ->
        respond Unhandled

  let side_loaded_tag =
    Side_loaded.create ~name:"foo"
      ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
      ~feature_flags:Plonk_types.Features.none ~typ:Field.typ

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N1)
          ~name:"side_loaded_main__simple_chain"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = [ side_loaded_tag ]
              ; feature_flags = Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    let prev =
                      exists Field.typ ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Proof )
                    in
                    let vk =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Verifier_index )
                    in
                    as_prover (fun () ->
                        let vk =
                          As_prover.read (Typ.prover_value ()) vk
                        in
                        Side_loaded.in_prover side_loaded_tag vk ) ;
                    let vk =
                      exists Side_loaded.Verification_key.typ
                        ~compute:(fun () ->
                          As_prover.read (Typ.prover_value ()) vk )
                    in
                    Side_loaded.in_circuit side_loaded_tag vk ;
                    let is_base_case = Field.equal Field.zero self in
                    let self_correct = Field.(equal (one + prev) self) in
                    Boolean.Assert.any [ self_correct; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = prev
                            ; proof
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example1 =
    let (), (), b1 =
      Common.time "b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              let%bind.Promise vk =
                Side_loaded.Verification_key.of_compiled_promise No_recursion.tag
              in
              step
                ~handler:
                  (handler No_recursion.example_input
                     (Side_loaded.Proof.of_proof No_recursion.example_proof)
                     vk )
                Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
    (Field.Constant.one, b1)
end

(* M1 dry-run: locate the data structures we'd serialize for the
   side-loaded child fixture (No_recursion's b0). No file writes yet —
   just printf the shapes/sizes so we can confirm we have hooks on
   everything PS's Sideload.Loader expects. *)
(* Side-loaded child (= No_recursion's b0) fixture writer.
 *
 * == Output schema (decision: match dump_nrr_fixtures exactly) ==
 *
 *   <output_dir>/vk.serde.json    : kimchi VerifierIndex (Fq) serde JSON
 *                                   (21 top-level keys; same Rust codec as
 *                                   dump_nrr_fixtures.ml:54)
 *   <output_dir>/proof.serde.json : kimchi proof (Fq) serde JSON, with
 *                                   `prev_challenges` already populated via
 *                                   Wrap_hack.pad_accumulator (5 top-level
 *                                   keys; same as dump_nrr_fixtures.ml:94)
 *   <output_dir>/wrapping.json    : Pickles wrapping via yojson_full —
 *                                   carries deferred-values + branch_data +
 *                                   sponge digest + prev_evals + redundant
 *                                   wire_proof bytes (3 top-level keys; same
 *                                   as dump_nrr_fixtures.ml:101)
 *   <output_dir>/statement.json   : public-state field encoded as yojson.
 *                                   For No_recursion (Input mode), this is
 *                                   the public INPUT supplied to `step`
 *                                   (= `Field.Constant.zero`); for an
 *                                   Output-mode rule it would be the
 *                                   public_output. The schema is identical
 *                                   regardless of mode (a single field).
 *
 * Activated by env var [SIDELOAD_FIXTURE_DIR]. When unset, no files are
 * written (the printfs still fire as a sanity log).
 *
 * == Why match nrr/ exactly, not extend ==
 *
 * PS's existing `Test.Pickles.Sideload.Loader.loadFixture` reads these
 * four file names with these schemas. Matching the schema verbatim
 * means the loader consumes our output without code changes — load is
 * a pure deserialization, no PS work.
 *
 * The side-loaded protocol DOES carry extra metadata
 * (`max_proofs_verified` and `actual_wrap_domain_size` from
 * `Side_loaded.Verification_key.t`), but neither needs a separate
 * fixture file:
 *
 *   * `actual_wrap_domain_size` is reconstructible PS-side from the
 *     kimchi VK's `domain.log_size_of_group` via the same formula
 *     `compile.ml:1031-1032` uses
 *     (`Common.actual_wrap_domain_size ~log_2_domain_size`).
 *   * `max_proofs_verified` is statically known per rule and gets
 *     baked into the test as a type-level parameter (= N0 here, since
 *     No_recursion has no prevs).
 *
 * Both are pinned at the test site by construction. Any disagreement
 * between OCaml's `Side_loaded.Verification_key.of_compiled_promise`
 * and the PS-side reconstruction would manifest as a witness
 * divergence in the loop, surfacing as a clean signal rather than
 * being silently masked by a duplicate field in the fixture.
 *
 * == Output location ==
 *
 * Caller picks via SIDELOAD_FIXTURE_DIR. The committed fixture lives
 * at `packages/pickles/test/fixtures/sideload_main_child/` (see the
 * README there for which OCaml run produced it and how to regenerate).
 *)
let dump_child_fixture () =
  let open No_recursion in
  let out_dir_opt = Sys.getenv_opt "SIDELOAD_FIXTURE_DIR" in
  Format.printf "=== side-loaded child fixture dump ===@." ;
  ( match out_dir_opt with
  | Some d -> Format.printf "  output_dir = %s@." d
  | None ->
      Format.printf
        "  SIDELOAD_FIXTURE_DIR not set — running in inspection-only mode@." ) ;

  let write_file rel data =
    match out_dir_opt with
    | Some d ->
        let path = d ^ "/" ^ rel in
        Out_channel.write_all path ~data ;
        Format.printf "  wrote %s (%d bytes)@." rel (String.length data)
    | None -> Format.printf "  [skip] would write %s (%d bytes)@." rel (String.length data)
  in

  (* (a) Side-loaded VK sanity-construct (record fields stay abstract;
     not dumped — PS reconstructs from kimchi VK + static mpv). *)
  let _sl_vk : Side_loaded.Verification_key.t =
    Promise.block_on_async_exn (fun () ->
        Side_loaded.Verification_key.of_compiled_promise tag )
  in
  Format.printf "(a) Side_loaded.Verification_key.of_compiled_promise: OK@." ;

  (* (b) Kimchi VK → vk.serde.json (Fq codec, same as nrr fixture). *)
  let kvk =
    Promise.block_on_async_exn (fun () ->
        Lazy.force Proof.verification_key_promise )
  in
  let vk_json =
    Kimchi_bindings.Protocol.VerifierIndex.Fq.to_serde_json
      (Pickles.Verification_key.index kvk)
  in
  write_file "vk.serde.json" vk_json ;

  (* (c) Wrap proof → proof.serde.json (Fq codec, same as nrr fixture).
     Uses Obj.magic to reach the inner wire_proof, computes
     pad_accumulator chal_polys mirroring `verify.ml:215-227` for the
     mpv=0 case (length 2), folds into backend proof, then serializes. *)
  let b0_concrete : Nat.N0.n Mina_wire_types.Pickles.Concrete_.Proof.t =
    Obj.magic example_proof
  in
  let (Mina_wire_types.Pickles.Concrete_.Proof.T b0_inner) = b0_concrete in
  let chal_polys_padded =
    Pickles.Wrap_hack.pad_accumulator
      (Vector.map2
         ~f:(fun g cs ->
           { Pickles.Backend.Tock.Proof.Challenge_polynomial.challenges =
               Vector.to_array (Pickles.Common.Ipa.Wrap.compute_challenges cs)
           ; commitment = g
           } )
         (Vector.extend_front_exn
            b0_inner.statement.messages_for_next_step_proof
              .challenge_polynomial_commitments Nat.N0.n
            (Lazy.force Pickles.Dummy.Ipa.Wrap.sg) )
         b0_inner.statement.proof_state.messages_for_next_wrap_proof
           .old_bulletproof_challenges )
  in
  let kimchi_proof =
    Pickles.Wrap_wire_proof.to_kimchi_proof b0_inner.proof
  in
  let with_pe : Pickles.Backend.Tock.Proof.with_public_evals =
    { proof = kimchi_proof; public_evals = None }
  in
  let backend_proof =
    Pickles.Backend.Tock.Proof.to_backend_with_public_evals'
      chal_polys_padded [||] with_pe
  in
  let proof_json =
    Kimchi_bindings.Protocol.Proof.Fq.to_serde_json backend_proof
  in
  write_file "proof.serde.json" proof_json ;

  (* (d) Pickles wrapping → wrapping.json (yojson_full, same as nrr
     fixture's wrapping.json). Carries deferred-work data the kimchi
     proof codec doesn't. *)
  let module ProofM = Pickles.Proof.Make (Nat.N0) in
  let wrapping_json = ProofM.to_yojson_full example_proof in
  write_file "wrapping.json" (Yojson.Safe.to_string wrapping_json) ;

  (* (e) Statement → statement.json. For No_recursion this is the
     public INPUT (= Field.Constant.zero); PS expects the same key
     ("statement.json") regardless of Input/Output mode. *)
  let stmt_json = Pickles.Backend.Tick.Field.to_yojson example_input in
  write_file "statement.json" (Yojson.Safe.to_string stmt_json) ;

  Format.printf "=== side-loaded child fixture dump DONE ===@."

let () =
  dump_child_fixture () ;
  let _ = Simple_chain.example1 in
  Format.printf "side-loaded main verified.@."
