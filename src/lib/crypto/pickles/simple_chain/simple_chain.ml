(* Executable demonstrating a Simple_chain recursive proof with a
   parameterized initial state.

   The public input of each proof is a pair [(initial, current)]. The base
   case requires [current = initial] (so any anchor works, not just zero).
   Every recursive step asserts both [prev_current + 1 = current] and
   [prev_initial = initial], so the anchor is carried through the chain and
   cannot be rewritten. *)

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Core_kernel.Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input :
        (Field.Constant.t * Field.Constant.t) Snarky_backendless.Request.t
    | Proof : Pickles_types.Nat.N1.n Proof.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t * Field.Constant.t)
      (proof : _ Proof.t) (Snarky_backendless.Request.With { request; respond })
      =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise ()
          ~public_input:(Input (Typ.tuple2 Field.typ Field.typ))
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N1)
          ~name:"blockchain-snark"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; prevs = [ self ]
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = initial, current } ->
                    let prev_initial, prev_current =
                      exists (Typ.tuple2 Field.typ Field.typ)
                        ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                    in
                    let is_base_case = Field.equal current initial in
                    let proof_must_verify = Boolean.not is_base_case in
                    let step_ok = Field.(equal (one + prev_current) current) in
                    let carry_ok = Field.equal prev_initial initial in
                    Boolean.Assert.any [ step_ok; is_base_case ] ;
                    Boolean.Assert.any [ carry_ok; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = (prev_initial, prev_current)
                            ; proof
                            ; proof_must_verify
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)
end

(* Truncate/create the file so that the kimchi bindings' [write] (which uses
   [OpenOptions::new().append(true).open(path)]) doesn't fail for a
   non-existent file and doesn't append onto stale bytes from a prior run. *)
let truncate_or_create path =
  Core_kernel.Out_channel.close (Core_kernel.Out_channel.create path)

(* If [SIMPLE_CHAIN_WRAP_VI_OUT] is set, write the wrap-circuit Kimchi
   VerifierIndex (Pallas) as msgpack, via the kimchi_bindings [write] function.
   The format matches what [rmp_serde::from_slice::<VerifierIndex<_, Pallas,
   SRS<Pallas>>>] on the Rust side expects. *)
let emit_wrap_vi_if_requested ~(pickles_vk : Pickles.Verification_key.t) =
  match Sys.getenv_opt "SIMPLE_CHAIN_WRAP_VI_OUT" with
  | None ->
      ()
  | Some path ->
      truncate_or_create path ;
      let index = Pickles.Verification_key.index pickles_vk in
      Kimchi_bindings.Protocol.VerifierIndex.Fq.write (Some true) index path ;
      Format.printf "wrote wrap VI (msgpack) to %s@." path

(* If [SIMPLE_CHAIN_WRAP_SRS_OUT] is set, write the wrap Kimchi SRS
   (Pallas) as msgpack. Same byte-level format as the Rust-side [SRS<Pallas>]
   rmp_serde encoding. *)
let emit_wrap_srs_if_requested ~(pickles_vk : Pickles.Verification_key.t) =
  match Sys.getenv_opt "SIMPLE_CHAIN_WRAP_SRS_OUT" with
  | None ->
      ()
  | Some path ->
      truncate_or_create path ;
      let index = Pickles.Verification_key.index pickles_vk in
      Kimchi_bindings.Protocol.SRS.Fq.write (Some true) index.srs path ;
      Format.printf "wrote wrap SRS (msgpack) to %s@." path

(* If [SIMPLE_CHAIN_WRAP_PROOF_OUT] is set, extract the inner wrap Kimchi proof
   (Pallas) from [pickles_proof] and write it as msgpack via the kimchi-stubs
   [caml_pasta_fq_plonk_proof_write] we added.

   The pickles [Proof.t] stores its wrap proof in the pickles-internal
   [Wrap_wire_proof.t] wire format. We:
     1. Convert [Wrap_wire_proof.t] -> [Backend.Tock.Proof.t]
        (a [Plonk_types.Proof.t] on Pallas).
     2. Wrap it as a [Backend.Tock.Proof.with_public_evals] with [public_evals
        = None], since the wire format doesn't carry them.
     3. Call [Backend.Tock.Proof.to_backend_with_public_evals'] to get a raw
        [Kimchi_types.proof_with_public] on Pallas.

   We deliberately pass empty [chal_polys] and empty [primary_input] because
   this demo stops at "the Rust side can deserialize the proof bytes"; the
   prev-challenges and wrap public input needed for an actual [verify] call
   are a separate problem (pickles' prepared-statement packing). The shape
   of the proof itself — commitments, bulletproof, evals, ft_eval1 — is the
   real output from [simple_chain]'s wrap circuit. *)
let emit_wrap_proof_if_requested
    ~(pickles_proof : Pickles_types.Nat.N1.n Pickles.Proof.t) =
  match Sys.getenv_opt "SIMPLE_CHAIN_WRAP_PROOF_OUT" with
  | None ->
      ()
  | Some path ->
      truncate_or_create path ;
      (* Pickles.Proof.t is abstract, but at runtime it's the concrete
         with_data variant exposed in Mina_wire_types.Pickles.Concrete_. Coerce
         through Obj.magic to reach the T constructor. *)
      let pickles_proof_concrete :
          Pickles_types.Nat.N1.n Mina_wire_types.Pickles.Concrete_.Proof.t =
        Obj.magic pickles_proof
      in
      let (Mina_wire_types.Pickles.Concrete_.Proof.T { proof = wire_proof; _ })
          =
        pickles_proof_concrete
      in
      let kimchi_proof = Pickles.Wrap_wire_proof.to_kimchi_proof wire_proof in
      let with_public_evals : Pickles.Backend.Tock.Proof.with_public_evals =
        { proof = kimchi_proof; public_evals = None }
      in
      let backend_proof =
        Pickles.Backend.Tock.Proof.to_backend_with_public_evals' [] [||]
          with_public_evals
      in
      Kimchi_bindings.Protocol.Proof.Fq.write (Some true) backend_proof path ;
      Format.printf "wrote wrap Kimchi proof (msgpack) to %s@." path

let () =
  let initial = Field.Constant.of_int 41 in
  let next = Field.Constant.of_int 42 in

  (* Base case: (initial=41, current=41). The previous-proof slot is a dummy
     that is not required to verify, because [current = initial] here. *)
  let dummy_prev_input =
    (Field.Constant.(negate one), Field.Constant.(negate one))
  in
  let dummy_prev_proof : Pickles_types.Nat.N1.n Pickles.Proof.t =
    Pickles.Proof.dummy Pickles_types.Nat.N1.n Pickles_types.Nat.N1.n
      ~domain_log2:14
  in
  let (), (), b0 =
    Common.time "b0" (fun () ->
        Promise.block_on_async_exn (fun () ->
            Simple_chain.step
              ~handler:(Simple_chain.handler dummy_prev_input dummy_prev_proof)
              (initial, initial) ) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Simple_chain.Proof.verify_promise [ ((initial, initial), b0) ] ) ) ;
  Format.printf "base-case proof verified, (initial, current) = (41, 41)@." ;

  (* Recursive step: (initial=41, current=42), prev = (41, 41) with proof b0. *)
  let (), (), b1 =
    Common.time "b1" (fun () ->
        Promise.block_on_async_exn (fun () ->
            Simple_chain.step
              ~handler:(Simple_chain.handler (initial, initial) b0)
              (initial, next) ) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Simple_chain.Proof.verify_promise [ ((initial, next), b1) ] ) ) ;
  Format.printf "recursive proof verified, (initial, current) = (41, 42)@." ;

  let _ = b0 in
  let _ = b1 in

  let pickles_vk : Pickles.Verification_key.t =
    Promise.block_on_async_exn (fun () ->
        Lazy.force Simple_chain.Proof.verification_key_promise )
  in
  emit_wrap_vi_if_requested ~pickles_vk ;
  emit_wrap_srs_if_requested ~pickles_vk ;
  emit_wrap_proof_if_requested ~pickles_proof:b1
