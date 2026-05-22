(** Side-load fixture dumper for the No_recursion_return application.
 *
 *  Outputs (under [output_dir]):
 *    - [vk.serde.json]    : kimchi `VerifierIndex` Rust serde JSON.
 *    - [proof.serde.json] : kimchi `ProverProof` Rust serde JSON, with
 *                           `prev_challenges` already populated. The PS
 *                           loader reads this directly via the existing
 *                           `vestaProofFromSerdeJson` FFI — same Rust
 *                           codec on both sides, no reconstruction.
 *    - [wrapping.json]    : Pickles `{ statement; prev_evals }` via
 *                           OCaml-yojson (`to_yojson_full`). Carries
 *                           the deferred-work data the kimchi proof
 *                           codec doesn't.
 *    - [statement.json]   : the application's public output.
 *)

open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let main output_dir =
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
  let module ProofM = Pickles.Proof.Make (Nat.N0) in
  let s0, (), b0 = Promise.block_on_async_exn (fun () -> step ()) in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s0, b0) ])) ;

  (* VK: kimchi serde JSON. *)
  let vk =
    Promise.block_on_async_exn (fun () ->
        Lazy.force Proof.verification_key_promise )
  in
  let vk_json =
    Kimchi_bindings.Protocol.VerifierIndex.Fq.to_serde_json
      (Pickles.Verification_key.index vk)
  in
  Out_channel.write_all (output_dir ^ "/vk.serde.json") ~data:vk_json ;

  (* Kimchi proof: extract the inner wire-proof + statement via
     Obj.magic on the abstract `Pickles.Proof.t` (same approach as
     `simple_chain.ml` in o1-labs/o1js-to-zkvm); compute chal_polys
     from the statement (mirrors `verify.ml:215-227` for NRR's mpv=0
     case, where `pad_accumulator []` produces 2 dummies); fold them
     into the kimchi backend proof; serialize via the shared kimchi
     serde codec. The PS loader consumes this directly. *)
  let b0_concrete : Nat.N0.n Mina_wire_types.Pickles.Concrete_.Proof.t =
    Obj.magic b0
  in
  let (Mina_wire_types.Pickles.Concrete_.Proof.T b0_inner) = b0_concrete in
  let chal_polys =
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
  let kimchi_proof = Pickles.Wrap_wire_proof.to_kimchi_proof b0_inner.proof in
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
  Out_channel.write_all (output_dir ^ "/proof.serde.json") ~data:proof_json ;

  (* Pickles wrapping (statement + prev_evals + redundant wire_proof
     bytes) via yojson. PS reads only the wrapping fields; the kimchi
     proof comes from `proof.serde.json`. *)
  let wrapping_json = ProofM.to_yojson_full b0 in
  Out_channel.write_all (output_dir ^ "/wrapping.json")
    ~data:(Yojson.Safe.to_string wrapping_json) ;
  let stmt_json = Pickles.Backend.Tick.Field.to_yojson s0 in
  Out_channel.write_all (output_dir ^ "/statement.json")
    ~data:(Yojson.Safe.to_string stmt_json)

let () =
  match Array.to_list Sys.argv with
  | _ :: output_dir :: _ ->
      main output_dir
  | _ ->
      eprintf "usage: dump_nrr_fixtures <output_dir>\n" ;
      exit 1
