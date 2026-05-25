(** Serde-JSON fixture dumper for the Tree_proof_return application — the
 *  N=2 (max_proofs_verified) HETEROGENEOUS-prev case.
 *
 *  Mirrors `dump_simple_chain_fixtures.ml` (same per-iteration serde-JSON
 *  output shape, loadable by the PureScript `loadNrrFixture`), but the
 *  application is Tree_proof_return (`test_no_sideloaded.ml:315-429` /
 *  `dump_tree_proof_return.ml`):
 *
 *    prevs                = [No_recursion_return.tag; self]
 *    max_proofs_verified  = N2,   per-slot widths = [0, 2]
 *    override_wrap_domain = N1  → self wrap_domains.h = 2^14
 *    public_input         = Output StepField
 *
 *  Slot 0 is a real No_recursion_return proof (always verified, reused
 *  across iterations); slot 1 is the previous Tree proof (a dummy N2 in the
 *  base case b0, then the real prior Tree proof for b1+).
 *
 *  Outputs per iteration `<output_dir>/wrap{0,1,2}/`:
 *    - vk.serde.json    : kimchi `VerifierIndex` Rust serde JSON.
 *    - proof.serde.json : kimchi wrap `ProverProof` Rust serde JSON.
 *    - public_input_skeleton.json    : Pickles `{ statement; prev_evals }` (yojson,
 *                         redundant `proof` key dropped).
 *    - app_statement.json   : the application public output (`self`).
 *)

open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

(* ---- Rule 1: No_recursion_return (leaf, N0, Output mode, returns 0) ---- *)
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

  let example =
    let res, (), b0 = Promise.block_on_async_exn (fun () -> step ()) in
    assert (Impls.Step.Field.Constant.(equal zero) res) ;
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (res, b0) ])) ;
    (res, b0)
end

(* ---- Rule 2: Tree_proof_return (N2, Output mode, heterogeneous prevs) ---- *)
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

let main output_dir =
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
  let module ProofM = Pickles.Proof.Make (Nat.N2) in
  let vk =
    Promise.block_on_async_exn (fun () ->
        Lazy.force Proof.verification_key_promise )
  in
  let vk_json =
    Kimchi_bindings.Protocol.VerifierIndex.Fq.to_serde_json
      (Pickles.Verification_key.index vk)
  in

  (* Dump iteration [idx]'s wrap proof — identical serde extraction to
     dump_simple_chain_fixtures, with max_proofs_verified = N2. *)
  let dump_one idx (self : Backend.Tick.Field.t) (b : Nat.N2.n Pickles.Proof.t) =
    let dir = sprintf "%s/wrap%d" output_dir idx in
    Out_channel.write_all (dir ^ "/vk.serde.json") ~data:vk_json ;
    let b_concrete : Nat.N2.n Mina_wire_types.Pickles.Concrete_.Proof.t =
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
                .challenge_polynomial_commitments Nat.N2.n
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

  (* Prove + verify + dump the chain. Base case b0: slot 0 = real NRR proof,
     slot 1 = dummy N2 (domain_log2=15, not verified). b1/b2: slot 1 = the
     previous real Tree proof. *)
  let s_neg_one = Backend.Tick.Field.(negate one) in
  let b_neg_one : Nat.N2.n Pickles.Proof.t =
    Obj.magic (Pickles.Proof.dummy Nat.N2.n Nat.N2.n ~domain_log2:15)
  in
  let s0, (), b0 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler true No_recursion_return.example (s_neg_one, b_neg_one)) () )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s0, b0) ])) ;
  dump_one 0 s0 b0 ;

  let s1, (), b1 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler false No_recursion_return.example (s0, b0)) () )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s1, b1) ])) ;
  dump_one 1 s1 b1 ;

  let s2, (), b2 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler false No_recursion_return.example (s1, b1)) () )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () -> Proof.verify_promise [ (s2, b2) ])) ;
  dump_one 2 s2 b2

let () =
  match Array.to_list Sys.argv with
  | _ :: output_dir :: _ ->
      main output_dir
  | _ ->
      eprintf "usage: dump_tree_proof_return_fixtures <output_dir>\n" ;
      exit 1
