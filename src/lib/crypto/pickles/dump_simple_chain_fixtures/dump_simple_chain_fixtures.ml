(** Fixture dumper for the Simple_chain application.
 *
 *  Proves the first three chain iterations (b0 base, b1, b2) of the
 *  `prev + 1` Simple_chain rule (max_proofs_verified = N1, same rule as
 *  `dump_simple_chain.ml` / `test_no_sideloaded.ml`) and, for each, dumps
 *  the WRAP proof in exactly the same serde-JSON form as
 *  `dump_nrr_fixtures.ml` — one self-contained fixture directory per
 *  iteration, [<output_dir>/wrap0], [wrap1], [wrap2], each containing:
 *
 *    - [vk.serde.json]    : kimchi `VerifierIndex` Rust serde JSON.
 *    - [proof.serde.json] : kimchi wrap `ProverProof` Rust serde JSON, with
 *                           `prev_challenges` already populated. Read back
 *                           directly via the same Rust codec
 *                           (`vestaProofFromSerdeJson`), no reconstruction.
 *    - [public_input_skeleton.json]    : Pickles `{ statement; prev_evals }` via
 *                           OCaml-yojson (`to_yojson_full`).
 *    - [app_statement.json]   : the application public input (`self`).
 *
 *  The per-iteration sub-directories are expected to exist already (the
 *  `dump-simplechain-fixtures` make target `mkdir -p`s them), mirroring
 *  `dump_nrr_fixtures`'s assumption that `output_dir` exists.
 *)

open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

(* Inductive rule: identical to `dump_simple_chain.ml` / Simple_chain. *)
type _ Snarky_backendless.Request.t +=
  | Prev_input : Backend.Tick.Field.t Snarky_backendless.Request.t
  | Proof : Pickles_types.Nat.N1.n Pickles.Proof.t Snarky_backendless.Request.t

let handler (prev_input : Backend.Tick.Field.t) (proof : _ Pickles.Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Prev_input ->
      respond (Provide prev_input)
  | Proof ->
      respond (Provide proof)
  | _ ->
      respond Unhandled

let main output_dir =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise () ~public_input:(Input Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N1)
      ~name:"simple_chain"
      ~choices:(fun ~self ->
        [ { identifier = "main"
          ; prevs = [ self ]
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self } ->
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      Prev_input )
                in
                let proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Proof)
                in
                let is_base_case =
                  Impls.Step.Field.equal Impls.Step.Field.zero self
                in
                let proof_must_verify = Impls.Step.Boolean.not is_base_case in
                let self_correct = Impls.Step.Field.(equal (one + prev) self) in
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
  let module ProofM = Pickles.Proof.Make (Nat.N1) in
  let vk =
    Promise.block_on_async_exn (fun () ->
        Lazy.force Proof.verification_key_promise )
  in
  let vk_json =
    Kimchi_bindings.Protocol.VerifierIndex.Fq.to_serde_json
      (Pickles.Verification_key.index vk)
  in

  (* Dump iteration [idx]'s wrap proof in the dump_nrr_fixtures serde form.
     Same extraction, with the Simple_chain max_proofs_verified = N1. *)
  let dump_one idx (self : Backend.Tick.Field.t)
      (b : Nat.N1.n Pickles.Proof.t) =
    let dir = sprintf "%s/wrap%d" output_dir idx in
    Out_channel.write_all (dir ^ "/vk.serde.json") ~data:vk_json ;
    let b_concrete : Nat.N1.n Mina_wire_types.Pickles.Concrete_.Proof.t =
      Obj.magic b
    in
    let (Mina_wire_types.Pickles.Concrete_.Proof.T b_inner) = b_concrete in
    let chal_polys =
      Pickles.Wrap_hack.pad_accumulator
        (Vector.map2
           ~f:(fun g cs ->
             { Pickles.Backend.Tock.Proof.Challenge_polynomial.challenges =
                 Vector.to_array (Pickles.Common.Ipa.Wrap.compute_challenges cs)
             ; commitment = g
             } )
           (Vector.extend_front_exn
              b_inner.statement.messages_for_next_step_proof
                .challenge_polynomial_commitments Nat.N1.n
              (Lazy.force Pickles.Dummy.Ipa.Wrap.sg) )
           b_inner.statement.proof_state.messages_for_next_wrap_proof
             .old_bulletproof_challenges )
    in
    let kimchi_proof = Pickles.Wrap_wire_proof.to_kimchi_proof b_inner.proof in
    let with_pe : Pickles.Backend.Tock.Proof.with_public_evals =
      { proof = kimchi_proof; public_evals = None }
    in
    let backend_proof =
      Pickles.Backend.Tock.Proof.to_backend_with_public_evals' chal_polys [||]
        with_pe
    in
    let proof_json =
      Kimchi_bindings.Protocol.Proof.Fq.to_serde_json backend_proof
    in
    Out_channel.write_all (dir ^ "/proof.serde.json") ~data:proof_json ;
    (* Drop the redundant `proof` key: `to_yojson_full` emits
       {statement; prev_evals; proof}, but the wrap proof is already in
       `proof.serde.json` (Rust serde) — which is what PS reads. The PS
       loader consumes only `statement` + `prev_evals` here. *)
    let wrapping_json =
      match ProofM.to_yojson_full b with
      | `Assoc kvs ->
          `Assoc (List.filter kvs ~f:(fun (k, _) -> not (String.equal k "proof")))
      | other ->
          other
    in
    Out_channel.write_all (dir ^ "/public_input_skeleton.json")
      ~data:(Yojson.Safe.to_string wrapping_json) ;
    let stmt_json = Pickles.Backend.Tick.Field.to_yojson self in
    Out_channel.write_all (dir ^ "/app_statement.json")
      ~data:(Yojson.Safe.to_string stmt_json)
  in

  (* Prove + verify + dump the chain: b0 (base, self=0), b1 (self=1),
     b2 (self=2). Each iteration verifies the previous proof. *)
  let s_neg_one = Backend.Tick.Field.(negate one) in
  let b_neg_one : Nat.N1.n Pickles.Proof.t =
    Pickles.Proof.dummy Nat.N1.n Nat.N1.n ~domain_log2:14
  in
  let (), (), b0 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler s_neg_one b_neg_one) Backend.Tick.Field.zero )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Backend.Tick.Field.zero, b0) ] ) ) ;
  dump_one 0 Backend.Tick.Field.zero b0 ;

  let (), (), b1 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler Backend.Tick.Field.zero b0) Backend.Tick.Field.one )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Backend.Tick.Field.one, b1) ] ) ) ;
  dump_one 1 Backend.Tick.Field.one b1 ;

  let (), (), b2 =
    Promise.block_on_async_exn (fun () ->
        step
          ~handler:(handler Backend.Tick.Field.one b1)
          Backend.Tick.Field.(of_int 2) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Backend.Tick.Field.(of_int 2), b2) ] ) ) ;
  dump_one 2 Backend.Tick.Field.(of_int 2) b2

let () =
  match Array.to_list Sys.argv with
  | _ :: output_dir :: _ ->
      main output_dir
  | _ ->
      eprintf "usage: dump_simple_chain_fixtures <output_dir>\n" ;
      exit 1
